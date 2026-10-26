-- Máscara para columnas con tag sensitivity = restricted.
-- Ver el valor real solo si se pertenece al grupo autorizado.
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.security;

CREATE OR REPLACE FUNCTION ${gov_catalog}.security.mask_restricted(value STRING)
RETURNS STRING
COMMENT 'POL-SEC-003: enmascara datos restringidos salvo para grp-restricted-readers'
RETURN CASE WHEN is_account_group_member('grp-restricted-readers') THEN value ELSE '***' END;
