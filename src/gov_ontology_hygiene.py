"""Job gov_ontology_hygiene (condicional ONT, trimestral): propone deprecar activos sin uso.

Busca productos de datos (inventory.data_products) y métricas (semantic.metric_registry) sin lecturas en los
últimos N días según el lineage nativo (system.access.table_lineage) y deja PROPUESTAS en
semantic.ontology_hygiene_log. La decisión de deprecar es humana (Data Owner) y se registra en la misma tabla.
"""
from __future__ import annotations

from gov_specs import base_parser, id_of


def main() -> None:
    p = base_parser("Higiene de fuentes del contexto de la Ontology")
    p.add_argument("--days", type=int, default=90)
    a = p.parse_args()
    from pyspark.sql import SparkSession
    from gov_lib import Gov
    spark = SparkSession.builder.getOrCreate()
    gov, c = Gov(spark, a.gov_catalog), a.gov_catalog
    stale = spark.sql(f"""
        WITH assets AS (
            SELECT gold_object AS asset FROM {c}.inventory.data_products WHERE lifecycle_status <> 'DEPRECADO'
            UNION SELECT metric_view FROM {c}.semantic.metric_registry WHERE certification_status <> 'DEPRECADO')
        SELECT a.asset FROM assets a
        LEFT JOIN (SELECT DISTINCT source_table_full_name AS asset FROM system.access.table_lineage
                   WHERE event_date >= date_sub(current_date(), {int(a.days)})) u ON u.asset = a.asset
        WHERE a.asset IS NOT NULL AND u.asset IS NULL""").collect()
    rows = [{"action_id": id_of("hygiene", s.asset, a.days), "asset": s.asset, "action": "PROPUESTA_DEPRECAR",
             "reason": f"sin lecturas en {a.days} días (lineage)", "executed_at": gov._now(),
             "executed_by": "gov_ontology_hygiene"} for s in stale]
    gov.merge("semantic.ontology_hygiene_log", ["action_id"], rows)
    print(f"{len(rows)} activos propuestos para deprecación")


if __name__ == "__main__":
    main()
