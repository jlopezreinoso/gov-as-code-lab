-- T-11b (C-01, POL-01): tablas de gold sin tags gov_lab_owner o gov_lab_steward.
SELECT t.table_schema, t.table_name,
       max(CASE WHEN g.tag_name = 'gov_lab_owner' THEN 1 ELSE 0 END)   AS tiene_owner,
       max(CASE WHEN g.tag_name = 'gov_lab_steward' THEN 1 ELSE 0 END) AS tiene_steward
FROM system.information_schema.tables t
LEFT JOIN system.information_schema.table_tags g
  ON g.catalog_name = t.table_catalog AND g.schema_name = t.table_schema AND g.table_name = t.table_name
WHERE t.table_catalog = '${data_catalog}' AND t.table_schema = 'gold'
GROUP BY t.table_schema, t.table_name
HAVING tiene_owner = 0 OR tiene_steward = 0
