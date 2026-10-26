-- Devuelve violaciones: ALL PRIVILEGES sobre tablas del catálogo de datos.
SELECT grantee, table_schema, table_name
FROM system.information_schema.table_privileges
WHERE table_catalog = '${data_catalog}' AND privilege_type = 'ALL PRIVILEGES'
