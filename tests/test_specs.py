from pathlib import Path

import pytest

from gov_dsar import count_sql, dsar_delete_sql
from gov_specs import (SpecError, build_rows, diff_schema, expired_files, load_specs, split_targets, sql_files,
                       subst, validate)
from run_sql_file import statements


def test_h16_borrar_solo_en_tablas_base_y_recalcular_derivadas():
    rows = [{"uc_object": "c.bronze.pagos_raw", "table_type": "STREAMING_TABLE"},
            {"uc_object": "c.silver.pagos", "table_type": "MATERIALIZED_VIEW"},
            {"uc_object": "c.gold.pagos", "table_type": "MATERIALIZED_VIEW"},
            {"uc_object": "g.quality.dq_results", "table_type": "MANAGED"}]
    base, derived = split_targets(rows)
    assert [r["uc_object"] for r in base] == ["c.bronze.pagos_raw", "g.quality.dq_results"]
    assert [r["uc_object"] for r in derived] == ["c.silver.pagos", "c.gold.pagos"]
    h = "a" * 64
    assert dsar_delete_sql("c.bronze.pagos_raw", "email", h).startswith("DELETE FROM c.bronze.pagos_raw WHERE sha2(")
    assert count_sql("c.gold.pagos", "email", h).startswith("SELECT count(*) AS n FROM c.gold.pagos WHERE sha2(")
    with pytest.raises(ValueError):
        dsar_delete_sql("c.bronze.pagos_raw", "email; DROP", h)


def test_h18b_solo_vencen_archivos_mas_viejos_que_la_retencion():
    dia, ahora = 86_400_000, 100 * 86_400_000
    entries = [{"path": "/Volumes/c/b/landing/viejo.csv", "is_directory": False, "last_modified": ahora - 31 * dia},
               {"path": "/Volumes/c/b/landing/limite.csv", "is_directory": False, "last_modified": ahora - 30 * dia},
               {"path": "/Volumes/c/b/landing/nuevo.csv", "is_directory": False, "last_modified": ahora - 1 * dia},
               {"path": "/Volumes/c/b/landing/payhub", "is_directory": True, "last_modified": ahora - 90 * dia}]
    assert expired_files(entries, ahora, 30) == ["/Volumes/c/b/landing/viejo.csv"]

ROOT = Path(__file__).resolve().parents[1]
VARS = {"gov_catalog": "gov_dev", "data_catalog": "gov_manual_lab", "env": "dev"}


def test_plantillas_del_repo_son_validas():
    specs = load_specs(ROOT, VARS)
    validate(specs)
    rows = build_rows(specs, "abc123")
    assert {"org.policies", "org.standards", "risk_control.controls", "risk_control.control_tests",
            "inventory.data_contracts", "inventory.contract_columns", "quality.dq_rules", "org.projects"} <= rows.keys()
    contrato = rows["inventory.data_contracts"][1][0]
    assert contrato["uc_object"] == "gov_manual_lab.gold.pagos" and contrato["git_commit"] == "abc123"
    tipos = {c["column_name"]: c["data_type"] for c in rows["inventory.contract_columns"][1]}
    assert tipos["monto"] == "DECIMAL(12,2)"
    # Trazabilidad del expediente: 12 controles (17), 8 reglas DQ (15), 11 riesgos (16), 9 ADR (N10).
    assert {r["control_id"] for r in rows["risk_control.controls"][1]} == {f"C-{i:02d}" for i in range(1, 13)}
    assert {r["rule_id"] for r in rows["quality.dq_rules"][1]} == {f"DQ-{i:02d}" for i in range(1, 9)}
    assert len(rows["risk_control.risk_register"][1]) == 11 and len(rows["risk_control.adr_log"][1]) == 9
    riesgos = {r["risk_id"] for r in rows["risk_control.risk_register"][1]}
    assert {r["risk_id"] for r in rows["risk_control.controls"][1]} <= riesgos


def test_sql_de_implementacion_existe_y_se_divide():
    specs = load_specs(ROOT, VARS)
    files = sql_files(specs)
    assert files == ["governance_soft/metadata/certificacion_dp01.sql",
                     "governance_soft/masks/fn_pagos_security.sql", "governance_soft/abac/p_filter_country.sql",
                     "governance_soft/abac/p_mask_email.sql", "governance_soft/abac/grants_runner.sql",
                     "governance_soft/abac/grants_consumers.sql", "governance_soft/metadata/tags_dp01.sql"]
    for f in files:
        sql = subst((ROOT / f).read_text(encoding="utf-8"), VARS)
        assert "${" not in sql
        assert statements(sql)


def test_ddl_del_catalogo_se_divide_en_sentencias():
    stmts = statements(subst((ROOT / "sql/gov_catalog_ddl.sql").read_text(encoding="utf-8"),
                             {"gov_catalog": "gov_dev", "owner_group": "grp"}))
    creates = [s for s in stmts if "CREATE TABLE" in s]
    assert len(creates) == 90 and all(s.rstrip().endswith("')") for s in creates)


def test_pruebas_de_control_apuntan_a_archivos_existentes():
    rows = build_rows(load_specs(ROOT, VARS), "x")
    for t in rows["risk_control.control_tests"][1]:
        assert (ROOT / t["query_or_script_uri"]).exists(), t["test_id"]


def test_validate_reporta_todos_los_errores():
    malos = [
        {"kind": "registry", "table": "access.grants", "keys": ["id"], "rows": [{"id": None}], "_path": "a.yaml"},
        {"kind": "dq_rule", "rule_id": "R1", "uc_object": "c.s.t", "dimension": "x", "engine": "SQL",
         "expression": "1=1", "severity": "ERROR", "failure_action": "log", "owner": "o", "_path": "b.yaml"},
        {"kind": "contract", "contract_id": "C1", "version": "v2", "product_id": "P", "uc_object": "c.s.t",
         "status": "VIGENTE", "schema": [{"name": "a"}, {"name": "a"}], "_path": "c.yaml"},
        {"kind": "nada", "_path": "d.yaml"},
    ]
    with pytest.raises(SpecError) as e:
        validate(malos)
    msg = str(e.value)
    for esperado in ("no se carga por registro", "sin clave", "engine 'SQL'", "no es semver", "duplicadas", "kind 'nada'"):
        assert esperado in msg


def test_controles_que_comparten_politica_no_son_duplicados():
    base = {"kind": "control", "risk_id": "R", "policy_id": "POL-02", "domain": "d", "description": "x",
            "control_type": "Preventivo", "native_or_custom": "NATIVO", "evidence": "e", "owner": "o",
            "failure_action": "f", "status": "ACTIVO"}
    validate([dict(base, control_id="C-02", _path="a"), dict(base, control_id="C-03", _path="b")])
    with pytest.raises(SpecError, match="duplicado"):
        validate([dict(base, control_id="C-02", _path="a"), dict(base, control_id="C-02", _path="b")])


def test_diff_schema_detecta_add_drop_type_y_nulabilidad():
    contrato = [{"name": "id", "type": "STRING", "nullable": False},
                {"name": "monto", "type": "DECIMAL(18,2)", "nullable": False},
                {"name": "fecha", "type": "DATE", "nullable": False}]
    real = [{"name": "ID", "type": "string", "nullable": True},
            {"name": "monto", "type": "DOUBLE", "nullable": False},
            {"name": "email", "type": "STRING", "nullable": True}]
    tipos = {(e["change_type"], e["column_name"]) for e in diff_schema(contrato, real)}
    assert tipos == {("ADD", "email"), ("DROP", "fecha"), ("TYPE", "monto"), ("NULLABILITY", "id")}
    assert diff_schema(contrato, contrato) == []
