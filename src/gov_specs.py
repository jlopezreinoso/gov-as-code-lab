"""Lectura y validación de las especificaciones de gobierno (YAML en Git) y su conversión a filas.

Módulo puro: no depende de Spark, se prueba localmente con pytest.
Cada YAML declara `kind`: policy | tag | control | contract | dq_rule | registry.
"""
from __future__ import annotations

import datetime as dt
import json
import re
from pathlib import Path

import yaml

# Tablas que se cargan desde governance_soft/registry/<schema>.<tabla>.yaml (ver hoja 05_COMO_SE_CARGA).
REGISTRY_TABLES = {
    "access.sod_rules", "ai.agent_registry", "ai.ai_asset_registry", "ai.ai_risk_controls",
    "consumption.app_registry", "consumption.bi_reports_registry", "consumption.domain_interface_contracts",
    "inventory.asset_business_attributes", "inventory.business_glossary", "inventory.cde_registry",
    "inventory.data_products", "inventory.data_sources", "inventory.master_entities", "inventory.reference_code_lists",
    "org.business_decisions", "org.domains", "org.project_features", "org.projects", "org.raci_matrix",
    "org.role_assignments", "org.roles", "org.standards",
    "platform.cost_center_map", "platform.cross_region_flows", "platform.hms_migration_tracker",
    "platform.preview_decisions", "platform.region_topology", "platform.release_watch", "platform.slo_definitions",
    "privacy.retention_policies", "provenance.processing_config", "quality.acceptance_checks",
    "risk_control.adr_log", "risk_control.deliverables_status", "risk_control.golive_checklist",
    "risk_control.native_vs_custom", "risk_control.risk_register",
    "schema_change.cdc_registry", "schema_change.cdf_consumers", "schema_change.streaming_registry",
    "semantic.genie_agent_registry", "semantic.genie_benchmarks", "semantic.metric_equivalence_tests",
    "semantic.metric_registry", "sharing.data_licenses", "sharing.sharing_agreements",
}

REQUIRED = {
    "policy": ["policy_id", "version", "name", "category", "owner", "approved_by", "effective_from", "status"],
    "tag": ["key", "version", "allowed_values", "owner", "status"],
    "control": ["control_id", "risk_id", "policy_id", "domain", "description", "control_type",
                "native_or_custom", "evidence", "owner", "failure_action", "status"],
    "contract": ["contract_id", "version", "product_id", "uc_object", "status", "schema"],
    "dq_rule": ["rule_id", "uc_object", "dimension", "engine", "expression", "severity", "failure_action", "owner"],
    "registry": ["table", "keys", "rows"],
}
ID_FIELD = {"policy": "policy_id", "tag": "key", "control": "control_id", "contract": "contract_id",
            "dq_rule": "rule_id", "registry": "table"}
ENGINES = {"EXPECTATION", "DQ_MONITOR", "DQX", "CUSTOM"}
CONTROL_TYPES = {"Preventivo", "Detectivo", "Correctivo", "Compensatorio", "Preventivo/Detectivo"}
SEMVER = re.compile(r"^\d+\.\d+(\.\d+)?$")


class SpecError(ValueError):
    """Una o más especificaciones son inválidas."""


def subst(text: str, variables: dict[str, str]) -> str:
    """Reemplaza ${var}; deja intacto lo que no esté definido."""
    return re.sub(r"\$\{(\w+)\}", lambda m: variables.get(m.group(1), m.group(0)), text)


def _plain(v):
    """Normaliza valores YAML a texto para la carga (fechas ISO, booleanos en minúscula, listas/dict a JSON)."""
    if v is None:
        return None
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (dt.date, dt.datetime)):
        return v.isoformat()
    if isinstance(v, (list, dict)):
        return json.dumps(v, ensure_ascii=False, default=str)
    return str(v)


def load_specs(root: str | Path, variables: dict[str, str] | None = None) -> list[dict]:
    """Lee todos los YAML de <root>/governance, aplica variables y anota la ruta de origen."""
    root = Path(root)
    specs = []
    for path in sorted((root / "governance_soft").rglob("*.yaml")):
        if path.parent.name == "platform":  # settings.yaml lo consume gov_reconcile
            continue
        doc = yaml.safe_load(subst(path.read_text(encoding="utf-8"), variables or {}))
        if not isinstance(doc, dict):
            raise SpecError(f"{path}: el archivo debe ser un objeto YAML")
        doc["_path"] = path.relative_to(root).as_posix()
        specs.append(doc)
    return specs


def validate(specs: list[dict]) -> None:
    """Valida todas las especificaciones y reporta todos los errores juntos."""
    errors, seen = [], {}
    for s in specs:
        where, kind = s.get("_path", "?"), s.get("kind")
        if kind not in REQUIRED:
            errors.append(f"{where}: kind '{kind}' no soportado")
            continue
        errors += [f"{where}: falta '{k}'" for k in REQUIRED[kind] if s.get(k) in (None, "", [])]
        # La clave es la de cada kind: un control también trae policy_id y no debe usarse como identidad.
        ident = (kind, s.get(ID_FIELD[kind]), str(s.get("version", "")))
        if ident in seen:
            errors.append(f"{where}: duplicado de {seen[ident]}")
        seen[ident] = where
        if kind == "control" and s.get("control_type") not in CONTROL_TYPES:
            errors.append(f"{where}: control_type '{s.get('control_type')}' inválido")
        if kind == "control":
            for t in s.get("tests", []):
                if not t.get("test_id") or not t.get("query_or_script_uri"):
                    errors.append(f"{where}: cada test necesita test_id y query_or_script_uri")
        if kind == "contract":
            if not SEMVER.match(str(s.get("version", ""))):
                errors.append(f"{where}: versión '{s.get('version')}' no es semver")
            names = [c.get("name") for c in s.get("schema", [])]
            if len(names) != len(set(names)) or None in names:
                errors.append(f"{where}: columnas sin nombre o duplicadas en schema")
        if kind == "dq_rule" and s.get("engine") not in ENGINES:
            errors.append(f"{where}: engine '{s.get('engine')}' debe ser uno de {sorted(ENGINES)}")
        if kind == "tag" and not isinstance(s.get("allowed_values"), list):
            errors.append(f"{where}: allowed_values debe ser una lista")
        if kind == "registry":
            if s.get("table") not in REGISTRY_TABLES:
                errors.append(f"{where}: la tabla '{s.get('table')}' no se carga por registro")
            for i, row in enumerate(s.get("rows") or []):
                miss = [k for k in s.get("keys") or [] if row.get(k) in (None, "")]
                if miss:
                    errors.append(f"{where}: fila {i + 1} sin clave {miss}")
    if errors:
        raise SpecError("Especificaciones inválidas:\n  - " + "\n  - ".join(errors))


def sql_files(specs: list[dict]) -> list[str]:
    """Archivos SQL de implementación nativa (máscaras, políticas ABAC...), sin repetir y en orden de aparición."""
    out = []
    for s in specs:
        for f in (s.get("implementation") or {}).get("sql_files", []):
            if f not in out:
                out.append(f)
    return out


def build_rows(specs: list[dict], commit: str) -> dict[str, tuple[list[str], list[dict]]]:
    """Convierte las especificaciones en {tabla: (claves, filas)} listas para MERGE."""
    out: dict[str, tuple[list[str], list[dict]]] = {}

    def add(table, keys, row):
        out.setdefault(table, (keys, []))[1].append({k: _plain(v) for k, v in row.items()})

    for s in specs:
        k = s["kind"]
        if k == "policy":
            add("org.policies", ["policy_id", "version"], {c: s.get(c) for c in (
                "policy_id", "version", "name", "category", "owner", "approved_by",
                "effective_from", "review_date", "status", "document_uri")})
        elif k == "tag":
            add("org.standards", ["standard_id", "version"], {
                "standard_id": f"TAG-{s['key']}", "version": s["version"], "name": s["key"],
                "standard_type": "tagging", "rule_expression": {"allowed_values": s["allowed_values"],
                                                                "description": s.get("description")},
                "status": s["status"]})
        elif k == "control":
            add("risk_control.controls", ["control_id"], {c: s.get(c) for c in (
                "control_id", "project_id", "risk_id", "policy_id", "domain", "question", "description",
                "control_type", "native_or_custom", "databricks_capability", "custom_object", "evidence",
                "owner", "frequency", "failure_action", "status")})
            for t in s.get("tests", []):
                add("risk_control.control_tests", ["test_id"], {
                    "test_id": t["test_id"], "control_id": s["control_id"], "description": t.get("description"),
                    "expected": t.get("expected", "0 filas"), "automated": t.get("automated", True),
                    "query_or_script_uri": t["query_or_script_uri"], "environment": t.get("environment", "all")})
        elif k == "contract":
            add("inventory.data_contracts", ["contract_id", "version"], {
                "contract_id": s["contract_id"], "version": s["version"], "product_id": s["product_id"],
                "uc_object": s["uc_object"], "status": s["status"], "yaml_uri": s["_path"], "git_commit": commit,
                "compatibility": s.get("compatibility"), "approved_by": s.get("approved_by"),
                "effective_from": s.get("effective_from"), "deprecated_at": s.get("deprecated_at")})
            for c in s["schema"]:
                add("inventory.contract_columns", ["contract_id", "version", "column_name"], {
                    "contract_id": s["contract_id"], "version": s["version"], "column_name": c["name"],
                    "data_type": str(c.get("type", "STRING")).upper(), "nullable": c.get("nullable", True),
                    "allowed_values": c.get("allowed_values"), "classification": c.get("classification"),
                    "is_key": c.get("is_key", False)})
        elif k == "dq_rule":
            add("quality.dq_rules", ["rule_id"], {c: s.get(c) for c in (
                "rule_id", "project_id", "cde_id", "uc_object", "column_name", "dimension", "engine",
                "expression", "severity", "threshold", "failure_action", "owner", "enabled", "effective_from")})
        elif k == "registry":
            for row in s["rows"]:
                add(s["table"], list(s["keys"]), row)
    return out


def base_parser(description: str):
    """Argumentos comunes a todos los jobs de gobierno."""
    import argparse
    p = argparse.ArgumentParser(description=description)
    p.add_argument("--root", required=True, help="Raíz del bundle desplegado (${workspace.file_path})")
    p.add_argument("--gov-catalog", required=True)
    p.add_argument("--data-catalog", required=True)
    p.add_argument("--env", required=True)
    return p


def id_of(*parts) -> str:
    """Id determinista (idempotencia: el mismo evento no se duplica al reprocesar)."""
    import hashlib
    return hashlib.sha1("|".join("" if p is None else str(p) for p in parts).encode()).hexdigest()[:20]


# H-16: las vistas materializadas (y vistas) no admiten DELETE: se recalculan desde su tabla base con un refresh.
DERIVED_TYPES = {"MATERIALIZED_VIEW", "VIEW"}


def split_targets(rows) -> tuple[list, list]:
    """Separa las tablas base (DELETE directo) de las derivadas (se recalculan con el refresh del pipeline).
    Cada fila trae 'table_type' de system.information_schema.tables."""
    base = [r for r in rows if str(r["table_type"] or "").upper() not in DERIVED_TYPES]
    return base, [r for r in rows if r not in base]


def expired_files(entries, now_ms: int, retention_days: int) -> list[str]:
    """H-18b: archivos (no carpetas) de un volume cuya última modificación supera la retención.
    entries: dicts con 'path', 'is_directory' y 'last_modified' (epoch ms), como devuelve la Files API."""
    limit = now_ms - int(retention_days) * 86_400_000
    return [e["path"] for e in entries if not e["is_directory"] and int(e["last_modified"]) < limit]


def pending_migrations(files: list[str], applied: set[str]) -> list[str]:
    """Migraciones NNNN_descripcion.sql aún no aplicadas, en orden numérico."""
    def num(f):
        m = re.match(r"^(\d{4})_[\w-]+\.sql$", Path(f).name)
        if not m:
            raise SpecError(f"migración con nombre inválido: {f} (usar NNNN_descripcion.sql)")
        return int(m.group(1))
    ordered = sorted(files, key=num)
    nums = [num(f) for f in ordered]
    if len(nums) != len(set(nums)):
        raise SpecError("números de migración repetidos")
    return [f for f in ordered if Path(f).stem not in applied]


WRITERS = {"deployer", "runner", "app", "none"}


def grant_statements(gov_catalog: str, writers: dict[str, str], principals: dict[str, str]) -> list[str]:
    """GRANTs del catálogo de gobierno con separación de funciones.
    writers: {'esquema.tabla': deployer|runner|app}; principals: {deployer, runner, app, readers, auditors}.
    Lectura para readers en todo; MODIFY solo al escritor de cada tabla; auditores leen evidence y metadata."""
    q = lambda p: "`" + p + "`"
    c = gov_catalog
    out = [f"GRANT USE CATALOG ON CATALOG {c} TO {q(principals[k])}" for k in ("deployer", "runner", "app", "readers", "auditors")]
    schemas = sorted({t.split(".")[0] for t in writers} | {"evidence"})
    for s in schemas:
        for k in ("deployer", "runner", "app", "readers"):
            out.append(f"GRANT USE SCHEMA, SELECT ON SCHEMA {c}.{s} TO {q(principals[k])}")
    out.append(f"GRANT USE SCHEMA, SELECT ON SCHEMA {c}.evidence TO {q(principals['auditors'])}")
    out.append(f"GRANT READ METADATA ON CATALOG {c} TO {q(principals['auditors'])}")
    for t, w in sorted(writers.items()):
        if w not in WRITERS:
            raise SpecError(f"escritor inválido para {t}: {w}")
        if w != "none":
            out.append(f"GRANT MODIFY ON TABLE {c}.{t} TO {q(principals[w])}")
    return out


def diff_schema(contract: list[dict], actual: list[dict]) -> list[dict]:
    """Compara columnas contratadas vs reales. Cada elemento: {'name', 'type', 'nullable'}.
    Devuelve eventos de drift: ADD (columna nueva fuera de contrato), DROP (falta), TYPE y NULLABILITY."""
    norm = lambda t: re.sub(r"\s+", "", str(t or "")).upper()
    c = {x["name"].lower(): x for x in contract}
    a = {x["name"].lower(): x for x in actual}
    events = []
    for n in sorted(a.keys() - c.keys()):
        events.append({"change_type": "ADD", "column_name": n, "detail": f"columna fuera de contrato ({a[n]['type']})"})
    for n in sorted(c.keys() - a.keys()):
        events.append({"change_type": "DROP", "column_name": n, "detail": "columna contratada ausente"})
    for n in sorted(c.keys() & a.keys()):
        if norm(c[n]["type"]) != norm(a[n]["type"]):
            events.append({"change_type": "TYPE", "column_name": n, "detail": f"{c[n]['type']} → {a[n]['type']}"})
        elif bool(c[n].get("nullable", True)) is False and bool(a[n].get("nullable", True)) is True:
            events.append({"change_type": "NULLABILITY", "column_name": n, "detail": "contrato NOT NULL, real nullable"})
    return events
