"""Aplica los permisos del catálogo de gobierno con separación de funciones (tarea de gov_bootstrap).

Lee governance_soft/platform/table_writers.yaml y otorga:
  - SELECT a todos los grupos de gobierno; MODIFY solo al grupo que escribe cada tabla;
  - SELECT en evidence + READ METADATA a auditores.
Así nadie puede alterar la evidencia que produce otro proceso (GOV-ACC-005).
"""
from __future__ import annotations

from pathlib import Path

import yaml

from gov_specs import base_parser, grant_statements


def main() -> None:
    p = base_parser("Permisos del catálogo de gobierno")
    for k in ("deployer", "runner", "app", "readers", "auditors"):
        p.add_argument(f"--{k}-group", required=True)
    p.add_argument("--dry-run", action="store_true")
    a = p.parse_args()
    writers = yaml.safe_load((Path(a.root) / "governance_soft/platform/table_writers.yaml").read_text(encoding="utf-8"))["tables"]
    principals = {k: getattr(a, f"{k}_group") for k in ("deployer", "runner", "app", "readers", "auditors")}
    stmts = grant_statements(a.gov_catalog, writers, principals)
    if a.dry_run:
        print("\n".join(stmts))
        return
    from pyspark.sql import SparkSession
    spark = SparkSession.builder.getOrCreate()
    for s in stmts:
        spark.sql(s)
    print(f"{len(stmts)} GRANT aplicados en {a.gov_catalog}")


if __name__ == "__main__":
    main()
