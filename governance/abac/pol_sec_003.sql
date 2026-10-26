-- POL-SEC-003: política ABAC que aplica la máscara a toda columna con tag sensitivity = restricted
-- en el catálogo de datos del proyecto.
-- IMPORTANTE: validar la sintaxis de CREATE POLICY en tu runtime antes de usarla (ABAC evoluciona rápido;
-- ver https://docs.databricks.com/aws/en/data-governance/unity-catalog/abac/).
CREATE OR REPLACE POLICY pol_sec_003_mask_restricted
ON CATALOG ${data_catalog}
COMMENT 'POL-SEC-003'
COLUMN MASK ${gov_catalog}.security.mask_restricted
TO `account users`
EXCEPT `grp-restricted-readers`
FOR TABLES
MATCH COLUMNS has_tag_value('sensitivity', 'restricted') AS c
ON COLUMN c;
