-- Grants directos a usuarios en el catálogo de datos (GOV-ACC-001).
SELECT grantee, table_schema, table_name, privilege_type
FROM ${gov_catalog}.evidence.v_grants_to_users
WHERE table_catalog = '${data_catalog}'
