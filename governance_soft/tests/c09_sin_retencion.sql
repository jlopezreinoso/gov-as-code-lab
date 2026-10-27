-- T-13 (C-09, POL-05): tablas del catálogo de datos sin tags retention_policy y retention_column (gov_retention no las purga).
SELECT t.table_schema, t.table_name
FROM system.information_schema.tables t
LEFT JOIN system.information_schema.table_tags p
  ON p.catalog_name = t.table_catalog AND p.schema_name = t.table_schema AND p.table_name = t.table_name
 AND p.tag_name = 'retention_policy'
LEFT JOIN system.information_schema.table_tags c
  ON c.catalog_name = t.table_catalog AND c.schema_name = t.table_schema AND c.table_name = t.table_name
 AND c.tag_name = 'retention_column'
WHERE t.table_catalog = '${data_catalog}' AND t.table_schema IN ('bronze', 'silver', 'gold')
  AND (p.table_name IS NULL OR c.table_name IS NULL)
