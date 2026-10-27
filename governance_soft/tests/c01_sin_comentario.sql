-- T-11 (C-01, POL-06): tablas y columnas de silver/gold sin comentario.
SELECT table_schema, table_name, CAST(NULL AS STRING) AS column_name
FROM system.information_schema.tables
WHERE table_catalog = '${data_catalog}' AND table_schema IN ('silver', 'gold')
  AND (comment IS NULL OR trim(comment) = '')
UNION ALL
SELECT table_schema, table_name, column_name
FROM system.information_schema.columns
WHERE table_catalog = '${data_catalog}' AND table_schema IN ('silver', 'gold')
  AND (comment IS NULL OR trim(comment) = '')
