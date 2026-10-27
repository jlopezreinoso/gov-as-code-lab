"""Job gov_sync: aplica en Databricks lo declarado en Git y lo registra en el catálogo de gobierno.

Se ejecuta tras `databricks bundle deploy` (lo dispara el CI al hacer merge a main):
  1. Lee y valida governance_soft/**/*.yaml (falla si algo es inválido: nada se aplica a medias).
  2. Ejecuta los SQL de implementación nativa (máscaras, políticas ABAC, ...).
  3. MERGE idempotente en las tablas de gobierno (policies, standards, controls, contratos, reglas DQ, registros).
  4. Registra el despliegue en processing.deployment_assets.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from gov_specs import build_rows, load_specs, sql_files, validate


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--root", required=True, help="Raíz del bundle desplegado (${workspace.file_path})")
    p.add_argument("--gov-catalog", required=True)
    p.add_argument("--data-catalog", required=True)
    p.add_argument("--env", required=True)
    p.add_argument("--commit", default="local")
    p.add_argument("--project-id", default="GOV-AS-CODE")
    p.add_argument("--dry-run", action="store_true", help="Solo valida y muestra lo que cargaría")
    a = p.parse_args()

    variables = {"gov_catalog": a.gov_catalog, "data_catalog": a.data_catalog, "env": a.env}
    specs = load_specs(a.root, variables)
    validate(specs)
    rows = build_rows(specs, a.commit)
    print(f"{len(specs)} especificaciones válidas → " + ", ".join(f"{t}: {len(r)}" for t, (_, r) in rows.items()))
    if a.dry_run:
        return

    from pyspark.sql import SparkSession
    from gov_lib import Gov
    from run_sql_file import run_file

    spark = SparkSession.builder.getOrCreate()
    gov = Gov(spark, a.gov_catalog)
    for f in sql_files(specs):
        n = run_file(spark, Path(a.root) / f, variables)
        print(f"aplicado {f} ({n} sentencias)")
    for table, (keys, data) in rows.items():
        print(f"MERGE {table}: {gov.merge(table, keys, data)} filas")
    gov.merge("processing.deployment_assets", ["asset_id"], [{
        "asset_id": f"bundle:gov-as-code:{a.env}", "project_id": a.project_id, "asset_type": "bundle",
        "name": "gov-as-code", "environment": a.env, "bundle_name": "gov-as-code", "git_commit": a.commit,
        "deployed_at": gov._now(), "deployed_by": spark.sql("SELECT current_user() AS u").first()["u"]}])


if __name__ == "__main__":
    main()
