"""Job gov_reconcile: compara lo declarado contra lo real y registra resultados y desviaciones.

Secciones (cada una aislada: si una falla, las demás siguen y el error queda en el log):
  schema    → schema_change.schema_snapshots + schema_drift_events (contrato vs information_schema)
  controls  → risk_control.control_test_results (SQL de cada prueba: 0 filas = PASS)
  dq        → quality.dq_results (reglas con engine = CUSTOM)
  settings  → platform.platform_settings_baseline (governance/platform/settings.yaml vs Workspace Conf API)

--fail-on-control-fail hace fallar el job si alguna prueba de control da FAIL (se usa como gate en CI).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import traceback
from pathlib import Path

import yaml

from gov_specs import diff_schema, subst


def _id(*parts) -> str:
    return hashlib.sha1("|".join(map(str, parts)).encode()).hexdigest()[:20]


def reconcile_schema(spark, gov, cat: str) -> int:
    contracts = spark.sql(f"""
        SELECT c.contract_id, c.version, c.uc_object FROM {cat}.inventory.data_contracts c
        WHERE c.status = 'VIGENTE' AND c.uc_object IS NOT NULL""").collect()
    events = 0
    for c in contracts:
        parts = c.uc_object.split(".")
        if len(parts) != 3:
            print(f"uc_object inválido en {c.contract_id}: {c.uc_object}")
            continue
        actual = [{"name": r.column_name, "type": r.data_type, "nullable": r.is_nullable == "YES"} for r in spark.sql(f"""
            SELECT column_name, data_type, is_nullable FROM system.information_schema.columns
            WHERE table_catalog = '{parts[0]}' AND table_schema = '{parts[1]}' AND table_name = '{parts[2]}'
            ORDER BY ordinal_position""").collect()]
        contract = [{"name": r.column_name, "type": r.data_type, "nullable": r.nullable} for r in spark.sql(f"""
            SELECT column_name, data_type, nullable FROM {cat}.inventory.contract_columns
            WHERE contract_id = '{c.contract_id}' AND version = '{c.version}'""").collect()]
        now = gov._now()
        gov.merge("schema_change.schema_snapshots", ["uc_object", "captured_at"], [{
            "uc_object": c.uc_object, "captured_at": now, "columns_json": json.dumps(actual),
            "contract_id": c.contract_id, "contract_version": c.version}])
        if not actual:
            drift = [{"change_type": "MISSING_OBJECT", "column_name": None, "detail": "el objeto no existe"}]
        else:
            drift = diff_schema(contract, actual)
        rows = [{"event_id": _id(c.uc_object, e["change_type"], e["column_name"], c.version), "uc_object": c.uc_object,
                 "detected_at": now, "change_type": e["change_type"], "column_name": e["column_name"],
                 "contract_version": c.version, "action": e["detail"], "status": "ABIERTO"} for e in drift]
        gov.merge("schema_change.schema_drift_events", ["event_id"], rows)  # mismo evento abierto no se duplica
        events += len(rows)
    return events


def reconcile_controls(spark, gov, cat: str, root: Path, variables: dict) -> tuple[int, int]:
    tests = spark.sql(f"""
        SELECT test_id, query_or_script_uri FROM {cat}.risk_control.control_tests
        WHERE automated = true AND query_or_script_uri LIKE '%.sql'""").collect()
    run_id, fails, rows = _id("controls", gov._now()), 0, []
    for t in tests:
        try:
            sql = subst((root / t.query_or_script_uri).read_text(encoding="utf-8"), variables).strip().rstrip(";")
            df = spark.sql(sql)
            n = df.count()
            sample = [r.asDict() for r in df.limit(5).collect()]
            result, details = ("PASS", "0 violaciones") if n == 0 else ("FAIL", f"{n} violaciones: {json.dumps(sample, default=str)[:3000]}")
        except Exception as ex:  # una prueba rota es un FAIL, no un PASS
            result, details = "ERROR", str(ex)[:3000]
        fails += result != "PASS"
        rows.append({"result_id": _id(run_id, t.test_id), "test_id": t.test_id, "run_id": run_id,
                     "executed_at": gov._now(), "result": result, "evidence_uri": t.query_or_script_uri, "details": details})
    gov.merge("risk_control.control_test_results", ["result_id"], rows)
    return len(rows), fails


def reconcile_dq(spark, gov, cat: str) -> int:
    rules = spark.sql(f"""
        SELECT rule_id, uc_object, expression, threshold FROM {cat}.quality.dq_rules
        WHERE engine = 'CUSTOM' AND coalesce(enabled, true)""").collect()
    run_id, rows = _id("dq", gov._now()), []
    for r in rules:
        res = spark.sql(f"""SELECT count(*) AS n, sum(CASE WHEN ({r.expression}) THEN 0 ELSE 1 END) AS bad
                            FROM {r.uc_object}""").first()
        n, bad = int(res.n or 0), int(res.bad or 0)
        rate = 1.0 if n == 0 else (n - bad) / n
        rows.append({"result_id": _id(run_id, r.rule_id), "rule_id": r.rule_id, "run_id": run_id, "evaluated_at": gov._now(),
                     "records_checked": n, "records_failed": bad, "pass_rate": rate,
                     "status": "PASS" if rate >= float(r.threshold if r.threshold is not None else 1.0) else "FAIL"})
    gov.merge("quality.dq_results", ["result_id"], rows)
    return len(rows)


def reconcile_settings(gov, root: Path) -> int:
    path = root / "governance" / "platform" / "settings.yaml"
    if not path.exists():
        return 0
    settings = yaml.safe_load(path.read_text(encoding="utf-8")).get("workspace", [])
    from databricks.sdk import WorkspaceClient
    actual = WorkspaceClient().workspace_conf.get_status(keys=",".join(s["key"] for s in settings)) or {}
    rows = [{"setting_key": s["key"], "scope": "workspace", "expected_value": str(s["expected"]).lower(),
             "justification": s.get("justification"), "actual_value": None if actual.get(s["key"]) is None else str(actual[s["key"]]).lower(),
             "last_checked": gov._now()} for s in settings]
    for r in rows:
        r["compliant"] = r["actual_value"] == r["expected_value"]
    gov.merge("platform.platform_settings_baseline", ["setting_key", "scope"], rows)
    return len(rows)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--root", required=True)
    p.add_argument("--gov-catalog", required=True)
    p.add_argument("--data-catalog", required=True)
    p.add_argument("--env", required=True)
    p.add_argument("--only", default="schema,controls,dq,settings")
    p.add_argument("--fail-on-control-fail", action="store_true")
    a = p.parse_args()

    from pyspark.sql import SparkSession
    from gov_lib import Gov

    spark = SparkSession.builder.getOrCreate()
    gov, root = Gov(spark, a.gov_catalog), Path(a.root)
    variables = {"gov_catalog": a.gov_catalog, "data_catalog": a.data_catalog, "env": a.env}
    only, errors, control_fails = set(a.only.split(",")), [], 0
    steps = {
        "schema": lambda: print(f"schema: {reconcile_schema(spark, gov, a.gov_catalog)} eventos de drift"),
        "controls": lambda: _controls(),
        "dq": lambda: print(f"dq: {reconcile_dq(spark, gov, a.gov_catalog)} reglas evaluadas"),
        "settings": lambda: print(f"settings: {reconcile_settings(gov, root)} settings verificados"),
    }

    def _controls():
        nonlocal control_fails
        n, control_fails = reconcile_controls(spark, gov, a.gov_catalog, root, variables)
        print(f"controls: {n} pruebas, {control_fails} no PASS")

    for name, step in steps.items():
        if name in only:
            try:
                step()
            except Exception:
                errors.append(name)
                traceback.print_exc()
    if errors:
        raise SystemExit(f"Secciones con error: {errors}")
    if a.fail_on_control_fail and control_fails:
        raise SystemExit(f"{control_fails} pruebas de control no pasaron")


if __name__ == "__main__":
    main()
