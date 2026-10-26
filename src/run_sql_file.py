"""Ejecuta SQL con variables ${...}: el DDL del catálogo, archivos de implementación nativa y migraciones.

Migraciones (sql/migrations/NNNN_descripcion.sql): se aplican una sola vez, en orden; cada una queda
registrada en processing.deployment_assets (asset_type = 'migration'), que hace de tabla de control.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

from gov_specs import pending_migrations, subst


def statements(sql: str) -> list[str]:
    """Divide en sentencias por ';' al final de línea e ignora bloques que solo tienen comentarios."""
    out = []
    for chunk in re.split(r";\s*\n", sql + "\n"):
        body = "\n".join(l for l in chunk.splitlines() if not l.strip().startswith("--")).strip()
        if body:
            out.append(chunk.strip().rstrip(";"))
    return out


def run_file(spark, path: str | Path, variables: dict[str, str]) -> int:
    stmts = statements(subst(Path(path).read_text(encoding="utf-8"), variables))
    for s in stmts:
        spark.sql(s)
    return len(stmts)


def run_migrations(spark, folder: Path, variables: dict[str, str]) -> list[str]:
    from gov_lib import Gov
    gov = Gov(spark, variables["gov_catalog"])
    applied = {r.name for r in spark.sql(
        f"SELECT name FROM {variables['gov_catalog']}.processing.deployment_assets WHERE asset_type = 'migration'").collect()}
    done = []
    for f in pending_migrations([p.name for p in folder.glob("*.sql")], applied):
        n = run_file(spark, folder / f, variables)
        gov.merge("processing.deployment_assets", ["asset_id"], [{
            "asset_id": f"migration:{Path(f).stem}", "asset_type": "migration", "name": Path(f).stem,
            "environment": variables.get("env"), "deployed_at": gov._now()}])
        print(f"migración {f}: {n} sentencias")
        done.append(f)
    return done


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--file", help="Archivo SQL a ejecutar")
    p.add_argument("--migrations-dir", help="Carpeta de migraciones a aplicar")
    p.add_argument("--gov-catalog", required=True)
    p.add_argument("--owner-group", default="")
    p.add_argument("--data-catalog", default="")
    p.add_argument("--env", default="")
    a = p.parse_args()
    from pyspark.sql import SparkSession
    spark = SparkSession.builder.getOrCreate()
    variables = {"gov_catalog": a.gov_catalog, "owner_group": a.owner_group, "data_catalog": a.data_catalog, "env": a.env}
    if a.file:
        print(f"{run_file(spark, a.file, variables)} sentencias ejecutadas desde {a.file}")
    if a.migrations_dir:
        print(f"migraciones aplicadas: {run_migrations(spark, Path(a.migrations_dir), variables) or 'ninguna pendiente'}")


if __name__ == "__main__":
    main()
