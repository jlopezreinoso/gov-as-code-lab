-- C-04 (POL-02, ADR-001/002): máscara sobre toda columna con tag gov_lab_pii = email.
-- PII = desenmascarar, no da filas (ADR-002). Igual a la política creada a mano (EXC-02).
CREATE OR REPLACE POLICY p_mask_email
ON CATALOG ${data_catalog}
COMMENT 'CTRL-EMAIL: correo oculto salvo grupo PII'
COLUMN MASK ${data_catalog}.security.mask_email
TO `account users`
EXCEPT `g_gov_lab_pii`, `g_gov_lab_etl`
FOR TABLES
MATCH COLUMNS has_tag_value('gov_lab_pii', 'email') AS email_col
ON COLUMN email_col;
