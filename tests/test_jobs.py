"""Pruebas de la lógica pura de los jobs (sin Spark)."""
import datetime as dt
import re
from pathlib import Path

import pytest
import yaml

from gov_access_review import cycle_of, revoke_sql
from gov_ai_eval import normalize
from gov_dsar import dsar_delete_sql
from gov_genie_benchmarks import same_result
from gov_itsm_sync import map_ticket
from gov_retention import purge_sql
from gov_specs import SpecError, grant_statements, pending_migrations

ROOT = Path(__file__).resolve().parents[1]
PRINCIPALS = {k: f"grp-{k}" for k in ("deployer", "runner", "app", "readers", "auditors")}


def writers():
    return yaml.safe_load((ROOT / "governance/platform/table_writers.yaml").read_text(encoding="utf-8"))["tables"]


def test_table_writers_cubre_exactamente_las_tablas_del_ddl():
    ddl = (ROOT / "sql/gov_catalog_ddl.sql").read_text(encoding="utf-8")
    tablas = set(re.findall(r"CREATE TABLE IF NOT EXISTS \$\{gov_catalog\}\.(\w+\.\w+)", ddl))
    assert len(tablas) == 90 and set(writers()) == tablas


def test_grants_separan_funciones():
    stmts = grant_statements("gov_prd", writers(), PRINCIPALS)
    modify = [s for s in stmts if s.startswith("GRANT MODIFY")]
    assert len(modify) == 90
    assert "GRANT MODIFY ON TABLE gov_prd.org.policies TO `grp-deployer`" in stmts
    assert "GRANT MODIFY ON TABLE gov_prd.risk_control.control_test_results TO `grp-runner`" in stmts
    assert "GRANT MODIFY ON TABLE gov_prd.risk_control.exceptions TO `grp-app`" in stmts
    assert not any("MODIFY" in s and "grp-readers" in s for s in stmts)
    assert "GRANT READ METADATA ON CATALOG gov_prd TO `grp-auditors`" in stmts
    with pytest.raises(SpecError):
        grant_statements("c", {"org.x": "todos"}, PRINCIPALS)


def test_migraciones_en_orden_y_solo_pendientes():
    files = ["0002_b.sql", "0001_a.sql", "0010_c.sql"]
    assert pending_migrations(files, {"0001_a"}) == ["0002_b.sql", "0010_c.sql"]
    with pytest.raises(SpecError):
        pending_migrations(["1_mal.sql"], set())
    with pytest.raises(SpecError):
        pending_migrations(["0001_a.sql", "0001_b.sql"], set())
    assert pending_migrations([p.name for p in (ROOT / "sql/migrations").glob("*.sql")], set())


def test_sql_de_purga_y_dsar_son_seguros():
    assert purge_sql("c.s.t", "fecha_evento", 30) == "DELETE FROM c.s.t WHERE `fecha_evento` < date_sub(current_date(), 30)"
    with pytest.raises(ValueError):
        purge_sql("c.s.t", "x; DROP TABLE y", 30)
    h = "a" * 64
    assert dsar_delete_sql("c.s.t", "cliente_id", h).endswith(f"= '{h}'")
    for malo in ("123", "' OR 1=1 --", "A" * 64):
        with pytest.raises(ValueError):
            dsar_delete_sql("c.s.t", "cliente_id", malo)


def test_revocacion_y_ciclo_de_accesos():
    assert revoke_sql("TABLE c.s.t", "SELECT", "grp-x") == "REVOKE SELECT ON TABLE c.s.t FROM `grp-x`"
    with pytest.raises(ValueError):
        revoke_sql("c.s.t", "SELECT", "grp-x")
    assert cycle_of(dt.date(2026, 11, 3)) == "2026-Q4" and cycle_of(dt.date(2027, 1, 1)) == "2027-Q1"


def test_itsm_genie_y_evaluacion():
    t = {"number": "EXC1", "opened_by": {"display_value": "ana@x.com"}}
    assert map_ticket(t, {"number": "exception_id", "opened_by.display_value": "requested_by", "falta.x": "asset"},
                      {"status": "APROBADA"}) == {"exception_id": "EXC1", "requested_by": "ana@x.com", "asset": None, "status": "APROBADA"}
    assert same_result([(1, "a"), (2, None)], [(2, None), (1, "a")]) and not same_result([(1,)], [(2,)])
    assert normalize("  Hola   Mundo ") == "hola mundo" and normalize(None) == ""


def test_alertas_y_bundle_referencian_archivos_existentes():
    assert len(list((ROOT / "governance/alerts").glob("*.sql"))) >= 5
    jobs = yaml.safe_load((ROOT / "resources/gov_jobs.yml").read_text(encoding="utf-8"))["resources"]["jobs"]
    assert len(jobs) == 10
    for name, job in jobs.items():
        for t in job["tasks"]:
            f = (ROOT / "resources" / t["spark_python_task"]["python_file"]).resolve()
            assert f.exists(), (name, f)
    app = yaml.safe_load((ROOT / "resources/gov_app.yml").read_text(encoding="utf-8"))["resources"]["apps"]["gov_review"]
    assert (ROOT / "resources" / app["source_code_path"] / "app.py").resolve().exists()
