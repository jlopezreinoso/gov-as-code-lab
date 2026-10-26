"""Job gov_access_review.

--mode open-cycle (trimestral): crea en access.access_reviews una fila PENDIENTE por cada grant real del catálogo
    de datos (catálogo, schema y tabla), para que el Data Owner decida mantener o revocar desde la App/ITSM.
--mode expire (diario): detecta accesos temporales vencidos (access.temporary_access) y, con --revoke, los revoca.
    Convención de securable: 'TABLE cat.esq.tabla' | 'SCHEMA cat.esq' | 'CATALOG cat'.
"""
from __future__ import annotations

import datetime as dt

from gov_specs import base_parser, id_of

SOURCES = {
    "CATALOG": ("catalog_privileges", "catalog_name"),
    "SCHEMA": ("schema_privileges", "concat_ws('.', catalog_name, schema_name)"),
    "TABLE": ("table_privileges", "concat_ws('.', table_catalog, table_schema, table_name)"),
}


def cycle_of(day: dt.date) -> str:
    return f"{day.year}-Q{(day.month - 1) // 3 + 1}"


def revoke_sql(securable: str, privilege: str, principal: str) -> str:
    kind, _, name = securable.partition(" ")
    if kind.upper() not in SOURCES or not name:
        raise ValueError(f"securable inválido: '{securable}' (usar 'TABLE cat.esq.t', 'SCHEMA cat.esq' o 'CATALOG cat')")
    return f"REVOKE {privilege} ON {kind.upper()} {name} FROM `{principal}`"


def main() -> None:
    p = base_parser("Recertificación y expiración de accesos")
    p.add_argument("--mode", choices=["open-cycle", "expire"], required=True)
    p.add_argument("--default-reviewer", default="Data Owner del catálogo")
    p.add_argument("--revoke", action="store_true")
    a = p.parse_args()
    from pyspark.sql import SparkSession
    from gov_lib import Gov
    spark = SparkSession.builder.getOrCreate()
    gov, c = Gov(spark, a.gov_catalog), a.gov_catalog

    if a.mode == "open-cycle":
        cycle, rows = cycle_of(dt.date.today()), []
        for kind, (view, name_expr) in SOURCES.items():
            catcol = "table_catalog" if kind == "TABLE" else "catalog_name"
            for g in spark.sql(f"""SELECT DISTINCT grantee, privilege_type, {name_expr} AS obj
                                   FROM system.information_schema.{view}
                                   WHERE {catcol} = '{a.data_catalog}' AND inherited_from = 'NONE'""").collect():
                securable = f"{kind} {g.obj}"
                rows.append({"review_id": id_of(cycle, g.grantee, securable, g.privilege_type), "cycle": cycle,
                             "principal": g.grantee, "securable": securable, "privilege": g.privilege_type,
                             "reviewer": a.default_reviewer, "decision": "PENDIENTE"})
        # Solo se insertan revisiones nuevas: reabrir el ciclo nunca pisa decisiones ya tomadas
        existing = {r.review_id for r in spark.sql(f"SELECT review_id FROM {c}.access.access_reviews WHERE cycle = '{cycle}'").collect()}
        new = [r for r in rows if r["review_id"] not in existing]
        gov.merge("access.access_reviews", ["review_id"], new)
        print(f"ciclo {cycle}: {len(new)} revisiones nuevas ({len(rows)} grants directos)")
    else:
        expired = spark.sql(f"""SELECT grant_ref, principal_group, securable, privilege FROM {c}.access.temporary_access
                                WHERE revoked_at IS NULL AND expires_at < current_timestamp()""").collect()
        for e in expired:
            if a.revoke:
                spark.sql(revoke_sql(e.securable, e.privilege, e.principal_group))
                gov.merge("access.temporary_access", ["grant_ref"], [{"grant_ref": e.grant_ref, "revoked_at": gov._now()}])
            print(f"{'REVOCADO' if a.revoke else 'VENCIDO'}: {e.privilege} en {e.securable} para {e.principal_group}")
        if expired and not a.revoke:
            raise SystemExit(f"{len(expired)} accesos temporales vencidos sin revocar")


if __name__ == "__main__":
    main()
