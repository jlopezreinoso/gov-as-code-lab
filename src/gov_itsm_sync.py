"""Job gov_itsm_sync (condicional): trae decisiones humanas aprobadas en el ITSM (ServiceNow, Jira...) al catálogo.

Configuración en governance_soft/platform/itsm_mapping.yaml: URL, secreto y, por cada tipo de ticket, la tabla destino,
la clave y el mapeo campo_ticket → columna. Usar como alternativa a la App de revisión (no ambas para la misma tabla).
"""
from __future__ import annotations

from pathlib import Path

import yaml

from gov_specs import base_parser


def map_ticket(ticket: dict, fields: dict[str, str], constants: dict | None = None) -> dict:
    """Aplica el mapeo campo_ticket → columna. Soporta campos anidados 'a.b.c'."""
    def get(obj, path):
        for part in path.split("."):
            obj = obj.get(part) if isinstance(obj, dict) else None
        return obj
    row = {col: get(ticket, src) for src, col in fields.items()}
    row.update(constants or {})
    return row


def main() -> None:
    p = base_parser("Sincronización de decisiones desde el ITSM")
    a = p.parse_args()
    import requests
    from databricks.sdk.runtime import dbutils
    from pyspark.sql import SparkSession
    from gov_lib import Gov
    cfg = yaml.safe_load((Path(a.root) / "governance_soft/platform/itsm_mapping.yaml").read_text(encoding="utf-8"))
    token = dbutils.secrets.get(cfg["secret_scope"], cfg["secret_key"])
    gov = Gov(SparkSession.builder.getOrCreate(), a.gov_catalog)
    for flow in cfg["flows"]:
        resp = requests.get(cfg["base_url"].rstrip("/") + flow["path"], params=flow.get("params", {}),
                            headers={"Authorization": f"Bearer {token}", "Accept": "application/json"}, timeout=60)
        resp.raise_for_status()
        tickets = resp.json()
        for key in cfg.get("results_path", "").split("."):
            if key:
                tickets = tickets[key]
        rows = [map_ticket(t, flow["fields"], flow.get("constants")) for t in tickets]
        print(f"{flow['table']}: {gov.merge(flow['table'], flow['keys'], rows)} filas desde {flow['path']}")


if __name__ == "__main__":
    main()
