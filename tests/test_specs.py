from pathlib import Path

import pytest

from gov_specs import SpecError, build_rows, diff_schema, load_specs, sql_files, subst, validate
from run_sql_file import statements

ROOT = Path(__file__).resolve().parents[1]
VARS = {"gov_catalog": "gov_dev", "data_catalog": "ventas_dev", "env": "dev"}


def test_plantillas_del_repo_son_validas():
    specs = load_specs(ROOT, VARS)
    validate(specs)
    rows = build_rows(specs, "abc123")
    assert {"org.policies", "org.standards", "risk_control.controls", "risk_control.control_tests",
            "inventory.data_contracts", "inventory.contract_columns", "quality.dq_rules", "org.projects"} <= rows.keys()
    contrato = rows["inventory.data_contracts"][1][0]
    assert contrato["uc_object"] == "ventas_dev.gold.pedidos" and contrato["git_commit"] == "abc123"
    tipos = {c["column_name"]: c["data_type"] for c in rows["inventory.contract_columns"][1]}
    assert tipos["monto_total"] == "DECIMAL(18,2)"


def test_sql_de_implementacion_existe_y_se_divide():
    specs = load_specs(ROOT, VARS)
    files = sql_files(specs)
    assert files == ["governance/masks/mask_restricted.sql", "governance/abac/pol_sec_003.sql"]
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
