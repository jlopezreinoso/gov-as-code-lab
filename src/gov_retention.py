"""Job gov_retention (diario): aplica la retención por política y deja evidencia en privacy.purge_log.

Qué tablas se purgan lo dicen los TAGS NATIVOS de Unity Catalog (no una lista paralela):
  retention_policy = <policy_id de privacy.retention_policies>
  retention_column = <columna de fecha/timestamp que define la antigüedad>
Para cada tabla etiquetada:
  - si tiene un legal hold activo (privacy.legal_holds) → no se toca y se registra;
  - ttl_mechanism = AUTO_TTL → solo se verifica (la purga la hace Databricks);
  - ttl_mechanism = JOB → DELETE de filas vencidas y, con --vacuum, VACUUM.
"""
from __future__ import annotations

from gov_specs import base_parser


def purge_sql(uc_object: str, column: str, retention_days: int) -> str:
    if not column.replace("_", "").isalnum():
        raise ValueError(f"columna de retención inválida: {column}")
    return f"DELETE FROM {uc_object} WHERE `{column}` < date_sub(current_date(), {int(retention_days)})"


def main() -> None:
    p = base_parser("Retención y purga")
    p.add_argument("--vacuum", action="store_true", help="Ejecutar VACUUM tras la purga (respeta la retención de Delta)")
    a = p.parse_args()
    from pyspark.sql import SparkSession
    from gov_lib import Gov
    spark = SparkSession.builder.getOrCreate()
    gov, c = Gov(spark, a.gov_catalog), a.gov_catalog

    targets = spark.sql("""
        SELECT concat_ws('.', catalog_name, schema_name, table_name) AS uc_object,
               max(CASE WHEN tag_name = 'retention_policy' THEN tag_value END) AS policy_id,
               max(CASE WHEN tag_name = 'retention_column' THEN tag_value END) AS col
        FROM system.information_schema.table_tags
        WHERE tag_name IN ('retention_policy', 'retention_column')
        GROUP BY catalog_name, schema_name, table_name""").collect()
    policies = {r.policy_id: r for r in spark.sql(f"SELECT * FROM {c}.privacy.retention_policies").collect()}
    holds = {r.uc_object for r in spark.sql(f"""
        SELECT uc_object FROM {c}.privacy.legal_holds
        WHERE status = 'ACTIVO' AND (end_date IS NULL OR end_date >= current_date())""").collect()}

    for t in targets:
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
        if a.vacuum:
            spark.sql(f"VACUUM {t.uc_object}")
        gov.log_purge(t.uc_object, t.policy_id, deleted, a.vacuum, "DELETE por retención")
        print(f"{t.uc_object}: {deleted} filas purgadas")


if __name__ == "__main__":
    main()
