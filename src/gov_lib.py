"""Escritura en el catálogo de gobierno desde jobs y pipelines (requiere Spark / Databricks).

Uso desde un pipeline del proyecto:
    from gov_lib import Gov
    gov = Gov(spark, "gov_prd")
    run_id = gov.start_run("PRJ-VENTAS", "job_ventas_diario", git_commit="abc123")
    ...
    gov.log_quarantine("ventas_prd.silver.pedidos", "ventas_prd.silver.pedidos_quarantine", "monto negativo", 12)
    gov.end_run(run_id, "SUCCESS", records_in=1000, records_out=988)
"""
from __future__ import annotations

import uuid


def _q(name: str) -> str:
    return "`" + name.replace("`", "``") + "`"


class Gov:
    def __init__(self, spark, gov_catalog: str):
        self.spark, self.cat = spark, gov_catalog

    # ------------------------------------------------------------------ escritura genérica
    def merge(self, table: str, keys: list[str], rows: list[dict]) -> int:
        """MERGE idempotente por clave primaria. Castea al tipo de cada columna destino y completa auditoría."""
        if not rows:
            return 0
        from pyspark.sql.types import StringType, StructField, StructType

        fq = f"{self.cat}.{table}"
        target = {f.name: f.dataType.simpleString() for f in self.spark.table(fq).schema.fields}
        audit = {"created_at", "created_by", "updated_at", "updated_by"}
        unknown = sorted({c for r in rows for c in r} - set(target))
        if unknown:
            raise ValueError(f"{fq}: columnas inexistentes {unknown}")
        cols = [c for c in target if c not in audit and any(c in r for r in rows)]
        missing_keys = [k for k in keys if k not in cols]
        if missing_keys:
            raise ValueError(f"{fq}: faltan claves {missing_keys}")
        schema = StructType([StructField(c, StringType(), True) for c in cols])
        data = [tuple(None if r.get(c) is None else str(r.get(c)) for c in cols) for r in rows]
        view = f"_gov_src_{uuid.uuid4().hex[:8]}"
        self.spark.createDataFrame(data, schema).createOrReplaceTempView(view)
        src = ", ".join(f"CAST({_q(c)} AS {target[c]}) AS {_q(c)}" for c in cols)
        on = " AND ".join(f"t.{_q(k)} = s.{_q(k)}" for k in keys)
        upd = ", ".join([f"t.{_q(c)} = s.{_q(c)}" for c in cols if c not in keys]
                        + ["t.updated_at = current_timestamp()", "t.updated_by = current_user()"])
        ins_cols = ", ".join([_q(c) for c in cols] + ["created_at", "created_by", "updated_at", "updated_by"])
        ins_vals = ", ".join([f"s.{_q(c)}" for c in cols]
                             + ["current_timestamp()", "current_user()", "current_timestamp()", "current_user()"])
        self.spark.sql(f"""
            MERGE INTO {fq} t
            USING (SELECT {src} FROM {view}) s
            ON {on}
            WHEN MATCHED THEN UPDATE SET {upd}
            WHEN NOT MATCHED THEN INSERT ({ins_cols}) VALUES ({ins_vals})""")
        self.spark.catalog.dropTempView(view)
        return len(rows)

    def append(self, table: str, pk: str, row: dict) -> str:
        """Inserta un evento con id generado y devuelve el id."""
        row = {pk: row.get(pk) or uuid.uuid4().hex, **row}
        self.merge(table, [pk], [row])
        return row[pk]

    # ------------------------------------------------------------------ API para pipelines del proyecto
    def start_run(self, project_id: str, job_or_pipeline_id: str, config_id: str | None = None,
                  git_commit: str | None = None, triggered_by: str | None = None) -> str:
        return self.append("processing.processing_runs", "run_id", {
            "project_id": project_id, "job_or_pipeline_id": job_or_pipeline_id, "status": "RUNNING",
            "started_at": self._now(), "config_id": config_id, "git_commit": git_commit, "triggered_by": triggered_by})

    def end_run(self, run_id: str, status: str, records_in: int | None = None, records_out: int | None = None) -> None:
        self.merge("processing.processing_runs", ["run_id"], [{
            "run_id": run_id, "status": status, "ended_at": self._now(),
            "records_in": records_in, "records_out": records_out}])

    def log_error(self, run_id: str, stage: str, error_code: str, message: str, record_key: str | None = None) -> str:
        return self.append("processing.processing_errors", "error_id", {
            "run_id": run_id, "stage": stage, "error_code": error_code, "message": message[:4000],
            "record_key": record_key, "occurred_at": self._now()})

    def log_quarantine(self, uc_object: str, quarantine_table: str, reason: str, records: int) -> str:
        return self.append("quality.quarantine_registry", "quarantine_id", {
            "uc_object": uc_object, "quarantine_table": quarantine_table, "reason": reason,
            "records": records, "detected_at": self._now()})

    def log_purge(self, uc_object: str, policy_id: str, rows_deleted: int, vacuum_executed: bool,
                  evidence_uri: str | None = None) -> str:
        return self.append("privacy.purge_log", "purge_id", {
            "uc_object": uc_object, "policy_id": policy_id, "executed_at": self._now(),
            "rows_deleted": rows_deleted, "vacuum_executed": vacuum_executed, "evidence_uri": evidence_uri})

    def log_dsar_step(self, request_id: str, uc_object: str, action: str, rows_affected: int, verified: bool) -> None:
        self.merge("privacy.dsar_execution_log", ["request_id", "uc_object", "action"], [{
            "request_id": request_id, "uc_object": uc_object, "action": action, "executed_at": self._now(),
            "rows_affected": rows_affected, "verified": verified}])

    def enqueue_review(self, project_id: str, uc_object: str, record_key: str, field: str,
                       proposed_value: str, reason: str, priority: str = "MEDIA", assigned_to: str | None = None) -> str:
        return self.append("review.review_queue", "review_id", {
            "project_id": project_id, "uc_object": uc_object, "record_key": record_key, "field": field,
            "proposed_value": proposed_value, "reason": reason, "priority": priority,
            "queued_at": self._now(), "assigned_to": assigned_to, "status": "PENDIENTE"})

    def register_document(self, source_id: str, file_uri: str, sha256: str, **attrs) -> str:
        return self.append("provenance.source_manifest", "source_doc_id", {
            "source_id": source_id, "file_uri": file_uri, "sha256": sha256,
            "registered_at": self._now(), "status": attrs.pop("status", "REGISTRADO"), **attrs})

    def log_field_evidence(self, run_id: str, uc_object: str, record_key: str, field: str, value: str,
                           source_doc_id: str, page: int | None = None, citation: str | None = None,
                           confidence: float | None = None) -> str:
        return self.append("provenance.field_evidence", "evidence_id", {
            "run_id": run_id, "uc_object": uc_object, "record_key": record_key, "field": field, "value": value,
            "source_doc_id": source_doc_id, "page": page, "citation": citation, "confidence": confidence})

    def log_reconciliation(self, project_id: str, source: str, target: str, metric: str, window_start: str,
                           window_end: str, source_value: float, target_value: float, tolerance: float) -> str:
        diff = abs(source_value - target_value)
        return self.append("quality.reconciliation_results", "recon_id", {
            "project_id": project_id, "source": source, "target": target, "metric": metric,
            "window_start": window_start, "window_end": window_end, "source_value": source_value,
            "target_value": target_value, "difference": diff, "tolerance": tolerance,
            "status": "PASS" if diff <= tolerance else "FAIL"})

    def _now(self) -> str:
        return self.spark.sql("SELECT CAST(current_timestamp() AS STRING) AS t").first()["t"]
