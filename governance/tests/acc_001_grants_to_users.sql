-- Devuelve violaciones: privilegios otorgados directamente a usuarios (tienen @) en el catálogo de datos.
SELECT grantee, table_schema, table_name, privilege_type
FROM system.information_schema.table_privileges
WHERE table_catalog = '${data_catalog}' AND grantee LIKE '%@%'
