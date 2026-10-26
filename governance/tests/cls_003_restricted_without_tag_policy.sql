-- Devuelve violaciones: columnas que el contrato clasifica como 'restricted' pero que en Unity Catalog
-- no tienen el tag sensitivity = restricted (sin el tag, la política ABAC no se aplica).
SELECT cc.contract_id, dc.uc_object, cc.column_name
FROM ${gov_catalog}.inventory.contract_columns cc
JOIN ${gov_catalog}.inventory.data_contracts dc
  ON dc.contract_id = cc.contract_id AND dc.version = cc.version AND dc.status = 'VIGENTE'
LEFT JOIN system.information_schema.column_tags t
  ON concat_ws('.', t.catalog_name, t.schema_name, t.table_name) = dc.uc_object
 AND t.column_name = cc.column_name AND t.tag_name = 'sensitivity' AND t.tag_value = 'restricted'
WHERE cc.classification = 'restricted' AND t.column_name IS NULL
