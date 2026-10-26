"""Tarea de alertas (última tarea de gov_reconcile): ejecuta governance/alerts/*.sql.

Cada SQL devuelve las filas que requieren atención (0 filas = sin alerta). Si alguna alerta tiene filas, la tarea
falla y el job envía el correo configurado en email_notifications (on_failure). Sin servicios adicionales.
"""
from __future__ import annotations

from pathlib import Path

from gov_specs import base_parser, subst


def main() -> None:
    a = base_parser("Alertas de gobierno").parse_args()
    from pyspark.sql import SparkSession
    spark = SparkSession.builder.getOrCreate()
    variables = {"gov_catalog": a.gov_catalog, "data_catalog": a.data_catalog, "env": a.env}
    fired = []
    for f in sorted((Path(a.root) / "governance/alerts").glob("*.sql")):
        df = spark.sql(subst(f.read_text(encoding="utf-8"), variables).strip().rstrip(";"))
        n = df.count()
        print(f"{'ALERTA' if n else 'ok    '} {f.stem}: {n} filas")
        if n:
            df.show(10, truncate=80)
            fired.append(f"{f.stem} ({n})")
    if fired:
        raise SystemExit("Alertas de gobierno activas: " + ", ".join(fired))


if __name__ == "__main__":
    main()
