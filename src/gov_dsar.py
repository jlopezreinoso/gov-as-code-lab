"""Job gov_dsar: ejecuta solicitudes de supresión (derecho del titular) aprobadas.

Se dispara cuando cambia privacy.dsar_requests (table update trigger) o a demanda.
Las tablas con datos del titular se declaran con TAG NATIVO:  dsar_subject_key = <columna con el identificador>
(incluir tablas SCD2 e históricas). La solicitud guarda solo el hash SHA-256 del identificador (subject_ref_hash),
nunca el dato personal: el borrado compara sha2(columna, 256) = hash.

H-16: el DELETE solo aplica a tablas base (streaming/managed); las vistas materializadas se recalculan con un
refresh del pipeline (--refresh-pipeline) y luego se VERIFICA que el titular ya no esté en ninguna capa.
H-19: el job no cambia el estado de la solicitud (decisión humana del DPO): deja la evidencia en
privacy.dsar_execution_log, con un paso VERIFICADO por solicitud.
CDF y time travel conservan las filas hasta el VACUUM: se registra VACUUM_PENDIENTE (mantenimiento del pipeline
o gov_retention --vacuum).
"""
from __future__ import annotations

import re

from gov_specs import base_parser, split_targets

HASH = re.compile(r"^[0-9a-f]{64}$")


def dsar_delete_sql(uc_object: str, key_column: str, subject_hash: str) -> str:
    if not HASH.match(subject_hash or ""):
        raise ValueError("subject_ref_hash debe ser SHA-256 en hexadecimal (64 caracteres)")
    if not key_column.replace("_", "").isalnum():
        raise ValueError(f"columna inválida: {key_column}")
    return f"DELETE FROM {uc_object} WHERE sha2(CAST(`{key_column}` AS STRING), 256) = '{subject_hash}'"


def count_sql(uc_object: str, key_column: str, subject_hash: str) -> str:
    return dsar_delete_sql(uc_object, key_column, subject_hash).replace("DELETE FROM", "SELECT count(*) AS n FROM", 1)


def main() -> None:
    p = base_parser("Supresión de datos del titular (DSAR)")
    p.add_argument("--refresh-pipeline", default="", help="Pipeline que recalcula las tablas derivadas tras el DELETE")
    a = p.parse_args()
    from pyspark.sql import SparkSession
    from gov_lib import Gov, refresh_pipeline
    spark = SparkSession.builder.getOrCreate()
    gov, c = Gov(spark, a.gov_catalog), a.gov_catalog

    requests = spark.sql(f"""SELECT request_id, subject_ref_hash FROM {c}.privacy.dsar_requests
                             WHERE request_type = 'SUPRESION' AND status = 'APROBADA'
                               AND request_id NOT IN (SELECT request_id FROM {c}.privacy.dsar_execution_log
                                                      WHERE action = 'VERIFICADO' AND verified)""").collect()
    tables = spark.sql("""
        SELECT concat_ws('.', g.catalog_name, g.schema_name, g.table_name) AS uc_object, g.tag_value AS key_col, t.table_type
        FROM system.information_schema.table_tags g
        JOIN system.information_schema.tables t
          ON t.table_catalog = g.catalog_name AND t.table_schema = g.schema_name AND t.table_name = g.table_name
        WHERE g.tag_name = 'dsar_subject_key'""").collect()
    base, derived = split_targets(tables)
    if not requests:
        print("sin solicitudes aprobadas pendientes")
        return

    ok = {r.request_id: True for r in requests}
    for r in requests:
        for t in base:
            res = spark.sql(dsar_delete_sql(t.uc_object, t.key_col, r.subject_ref_hash)).first()
            rows = int(res["num_affected_rows"]) if res is not None and "num_affected_rows" in res.asDict() else -1
            left = spark.sql(count_sql(t.uc_object, t.key_col, r.subject_ref_hash)).first()["n"]
            gov.log_dsar_step(r.request_id, t.uc_object, "DELETE", rows, left == 0)
            gov.log_dsar_step(r.request_id, t.uc_object, "VACUUM_PENDIENTE", 0, False)
            ok[r.request_id] &= left == 0
            print(f"{r.request_id} {t.uc_object}: {rows} filas borradas, quedan {left}")

    state = refresh_pipeline(a.refresh_pipeline) if derived and a.refresh_pipeline else "SIN_REFRESH"
    print(f"refresh del pipeline: {state}")
    for r in requests:
        for t in derived:
            left = spark.sql(count_sql(t.uc_object, t.key_col, r.subject_ref_hash)).first()["n"]
            gov.log_dsar_step(r.request_id, t.uc_object, "RECALCULO", 0, state == "COMPLETED" and left == 0)
            ok[r.request_id] &= state == "COMPLETED" and left == 0
            print(f"{r.request_id} {t.uc_object}: quedan {left} tras el refresh")
        gov.log_dsar_step(r.request_id, "*", "VERIFICADO", len(base) + len(derived), ok[r.request_id])
        print(f"{r.request_id}: {'VERIFICADO en todas las capas' if ok[r.request_id] else 'REVISAR: quedaron filas'}")


if __name__ == "__main__":
    main()
