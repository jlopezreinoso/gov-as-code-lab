-- T-04 (C-04, SEC-04): columnas que el contrato clasifica como 'restringido' sin el tag gov_lab_pii en UC
-- (sin el tag, la máscara ABAC no se aplica).
SELECT cc.contract_id, dc.uc_object, cc.column_name
FROM ${gov_catalog}.inventory.contract_columns cc
JOIN ${gov_catalog}.inventory.data_contracts dc
  ON dc.contract_id = cc.contract_id AND dc.version = cc.version AND dc.status = 'VIGENTE'
LEFT JOIN system.information_schema.column_tags t
  ON concat_ws('.', t.catalog_name, t.schema_name, t.table_name) = dc.uc_object
 AND t.column_name = cc.column_name AND t.tag_name = 'gov_lab_pii'
WHERE cc.classification = 'restringido' AND t.column_name IS NULL
