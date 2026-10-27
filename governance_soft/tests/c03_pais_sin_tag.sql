-- T-03 (C-03, SEC-03): columnas 'pais' sin tag gov_lab_country = country_code (sin el tag, el filtro ABAC no aplica).
SELECT c.table_schema, c.table_name, c.column_name
FROM system.information_schema.columns c
LEFT JOIN system.information_schema.column_tags t
  ON t.catalog_name = c.table_catalog AND t.schema_name = c.table_schema AND t.table_name = c.table_name
 AND t.column_name = c.column_name AND t.tag_name = 'gov_lab_country' AND t.tag_value = 'country_code'
WHERE c.table_catalog = '${data_catalog}' AND c.table_schema IN ('silver', 'gold')
  AND c.column_name = 'pais' AND t.column_name IS NULL
  AND NOT startswith(c.table_name, '__materialization') AND NOT startswith(c.table_name, 'event_log_')
-- Excluye objetos internos del pipeline (almacenamiento de MVs y event log): no son productos de datos.
