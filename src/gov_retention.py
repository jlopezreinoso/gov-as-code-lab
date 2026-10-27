"""Job gov_retention (diario): aplica la retención por política y deja evidencia en privacy.purge_log.

Qué tablas se purgan lo dicen los TAGS NATIVOS de Unity Catalog (no una lista paralela):
  retention_policy = <policy_id de privacy.retention_policies>
  retention_column = <columna de fecha/timestamp que define la antigüedad>
Para cada tabla etiquetada:
  - si tiene un legal hold activo (privacy.legal_holds) → no se toca y se registra;
  - ttl_mechanism = AUTO_TTL → solo se verifica (la purga la hace Databricks);
  - ttl_mechanism = JOB → DELETE de filas vencidas y, con --vacuum, VACUUM (solo tablas managed/external;
    las streaming tables las mantiene el pipeline).
H-16: las vistas materializadas no admiten DELETE: se recalculan desde su tabla base con un refresh del pipeline
(--refresh-pipeline) cuando se purgó algo.
"""
from __future__ import annotations

from gov_specs import base_parser, split_targets


def purge_sql(uc_object: str, column: str, retention_days: int) -> str:
    if not column.replace("_", "").isalnum():
        raise ValueError(f"columna de retención inválida: {column}")
    return f"DELETE FROM {uc_object} WHERE `{column}` < date_sub(current_date(), {int(retention_days)})"


def main() -> None:
    p = base_parser("Retención y purga")
    p.add_argument("--vacuum", action="store_true", help="Ejecutar VACUUM tras la purga (respeta la retención de Delta)")
    p.add_argument("--refresh-pipeline", default="", help="Pipeline que recalcula las tablas derivadas tras la purga")
    a = p.parse_args()
    from pyspark.sql import SparkSession
    from gov_lib import Gov, refresh_pipeline
    spark = SparkSession.builder.getOrCreate()
    gov, c = Gov(spark, a.gov_catalog), a.gov_catalog

    targets = spark.sql("""
        SELECT concat_ws('.', g.catalog_name, g.schema_name, g.table_name) AS uc_object, max(t.table_type) AS table_type,
               max(CASE WHEN g.tag_name = 'retention_policy' THEN g.tag_value END) AS policy_id,
               max(CASE WHEN g.tag_name = 'retention_column' THEN g.tag_value END) AS col
        FROM system.information_schema.table_tags g
        JOIN system.information_schema.tables t
          ON t.table_catalog = g.catalog_name AND t.table_schema = g.schema_name AND t.table_name = g.table_name
        WHERE g.tag_name IN ('retention_policy', 'retention_column')
        GROUP BY g.catalog_name, g.schema_name, g.table_name""").collect()
    policies = {r.policy_id: r for r in spark.sql(f"SELECT * FROM {c}.privacy.retention_policies").collect()}
    holds = {r.uc_object for r in spark.sql(f"""
        SELECT uc_object FROM {c}.privacy.legal_holds
        WHERE status = 'ACTIVO' AND (end_date IS NULL OR end_date >= current_date())""").collect()}
    base, derived = split_targets(targets)

    purged = 0
    for t in base:
        pol = policies.get(t.policy_id)
        if pol is None or not t.col:
            print(f"{t.uc_object}: política '{t.policy_id}' o retention_column no definidas → revisar tags")
            continue
        if t.uc_object in holds:
            gov.log_purge(t.uc_object, t.policy_id, 0, False, "OMITIDO: legal hold activo")
            continue
        if (pol.ttl_mechanism or "").upper() == "AUTO_TTL":
            gov.log_purge(t.uc_object, t.policy_id, 0, False, "AUTO_TTL gestionado por Databricks")
            continue
        metrics = spark.sql(purge_sql(t.uc_object, t.col, pol.retention_days)).first()
        deleted = int(metrics["num_affected_rows"]) if metrics is not None and "num_affected_rows" in metrics.asDict() else -1
        vacuum = a.vacuum and str(t.table_type).upper() in ("MANAGED", "EXTERNAL")
        if vacuum:
            spark.sql(f"VACUUM {t.uc_object}")
        gov.log_purge(t.uc_object, t.policy_id, deleted, vacuum, "DELETE por retención")
        purged += max(deleted, 0)
        print(f"{t.uc_object}: {deleted} filas purgadas")

    state = refresh_pipeline(a.refresh_pipeline) if purged and derived and a.refresh_pipeline else "NO_REQUERIDO"
    for t in derived:
        gov.log_purge(t.uc_object, t.policy_id, 0, False, f"DERIVADA: recalculada por refresh del pipeline ({state})")
    print(f"tablas base={len(base)} derivadas={len(derived)} filas purgadas={purged} refresh={state}")


if __name__ == "__main__":
    main()
