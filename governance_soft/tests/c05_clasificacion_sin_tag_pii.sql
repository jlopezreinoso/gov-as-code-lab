-- T-05 (C-05, ADR-007): columnas que Data Classification marcó como PII (tags class.*) sin gov_lab_pii.
-- Cada fila abre un issue S2 (P16) y la columna se trata como restringida hasta revisión del Steward.
SELECT d.schema_name, d.table_name, d.column_name, d.tag_name AS clase_detectada
FROM system.information_schema.column_tags d
LEFT JOIN system.information_schema.column_tags p
  ON p.catalog_name = d.catalog_name AND p.schema_name = d.schema_name AND p.table_name = d.table_name
 AND p.column_name = d.column_name AND p.tag_name = 'gov_lab_pii'
WHERE d.catalog_name = '${data_catalog}'
  AND d.tag_name IN ('class.email_address', 'class.name', 'class.phone_number', 'class.location', 'class.ip_address')
  AND p.column_name IS NULL
  AND NOT startswith(d.table_name, '__materialization') AND NOT startswith(d.table_name, 'event_log_')
-- Excluye objetos internos del pipeline (almacenamiento de MVs y event log): no son productos de datos.
