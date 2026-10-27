-- T-14 (C-10, REG-04): tablas con columnas gov_lab_pii sin el tag de tabla dsar_subject_key (gov_dsar no las cubriría).
SELECT DISTINCT p.schema_name, p.table_name
FROM system.information_schema.column_tags p
LEFT JOIN system.information_schema.table_tags d
  ON d.catalog_name = p.catalog_name AND d.schema_name = p.schema_name AND d.table_name = p.table_name
 AND d.tag_name = 'dsar_subject_key'
WHERE p.catalog_name = '${data_catalog}' AND p.tag_name = 'gov_lab_pii' AND d.table_name IS NULL
  AND NOT startswith(p.table_name, '__materialization') AND NOT startswith(p.table_name, 'event_log_')
-- Excluye objetos internos del pipeline (almacenamiento de MVs y event log): no son productos de datos.
