-- POL-02 / C-03 / C-04: funciones de seguridad del catálogo de datos (usadas por las políticas ABAC de abac/).
-- Misma firma que las creadas a mano (EXC-02): filter_country(p STRING) BOOLEAN y mask_email(v STRING) STRING.
-- Las excepciones (g_gov_lab_pii, g_gov_lab_etl) las resuelve la política ABAC, no la función.

CREATE OR REPLACE FUNCTION ${data_catalog}.security.filter_country(p STRING)
RETURNS BOOLEAN
COMMENT 'C-03 (POL-02): una fila es visible solo para el grupo de su país (EC -> g_gov_lab_ec, PE -> g_gov_lab_pe).'
RETURN CASE
  WHEN p = 'EC' AND is_account_group_member('g_gov_lab_ec') THEN TRUE
  WHEN p = 'PE' AND is_account_group_member('g_gov_lab_pe') THEN TRUE
  ELSE FALSE
END;

-- ADR-004: máscara parcial (primera letra + dominio). Sin '@' no se expone nada.
CREATE OR REPLACE FUNCTION ${data_catalog}.security.mask_email(v STRING)
RETURNS STRING
COMMENT 'C-04 (POL-02, ADR-004): email enmascarado a***@dominio para quien no está en g_gov_lab_pii.'
RETURN CASE
  WHEN v IS NULL THEN NULL
  WHEN instr(v, '@') <= 1 THEN '***'
  ELSE concat(left(v, 1), '***@', substring_index(v, '@', -1))
END;
