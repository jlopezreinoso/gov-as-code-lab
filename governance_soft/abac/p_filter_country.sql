-- C-03 (POL-02, ADR-001): filtro de filas por país sobre toda columna con tag gov_lab_country = country_code.
-- Excepción: g_gov_lab_etl (solo contiene sp_etl_pagos, ADR-003). Igual a la política creada a mano (EXC-02).
CREATE OR REPLACE POLICY p_filter_country
ON CATALOG ${data_catalog}
COMMENT 'CTRL-COUNTRY: lectura limitada al pais autorizado'
ROW FILTER ${data_catalog}.security.filter_country
TO `account users`
EXCEPT `g_gov_lab_etl`
FOR TABLES
MATCH COLUMNS has_tag_value('gov_lab_country', 'country_code') AS country_col
USING COLUMNS (country_col);
