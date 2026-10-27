-- POL-06 / POL-01 / POL-05 / C-01, C-03, C-04, C-09, C-10: tags de las tablas del pipeline DP-01 (taxonomía 11).
-- Requiere que el pipeline lab_pagos_medallion ya haya publicado las tablas (orden: bootstrap → pipeline → sync).
-- retention_policy / retention_column / dsar_subject_key son los tags que leen gov_retention y gov_dsar.

-- bronze.pagos_raw (streaming table)
ALTER TABLE ${data_catalog}.bronze.pagos_raw SET TAGS ('gov_lab_domain' = 'pagos', 'gov_lab_owner' = 'randrade@labpagos.example', 'gov_lab_steward' = 'dvega@labpagos.example', 'gov_lab_sensitivity' = 'restringido', 'gov_lab_retention' = '90d', 'retention_policy' = 'RET-PAG-BRONZE', 'retention_column' = '_ingest_ts', 'dsar_subject_key' = 'email');
ALTER TABLE ${data_catalog}.bronze.pagos_raw ALTER COLUMN pais SET TAGS ('gov_lab_country' = 'country_code');
ALTER TABLE ${data_catalog}.bronze.pagos_raw ALTER COLUMN email SET TAGS ('gov_lab_pii' = 'email', 'gov_lab_sensitivity' = 'restringido');

-- silver.pagos (materialized view)
ALTER TABLE ${data_catalog}.silver.pagos SET TAGS ('gov_lab_domain' = 'pagos', 'gov_lab_owner' = 'randrade@labpagos.example', 'gov_lab_steward' = 'dvega@labpagos.example', 'gov_lab_sensitivity' = 'restringido', 'gov_lab_retention' = '7y', 'retention_policy' = 'RET-PAG-TRANSACC', 'retention_column' = 'fecha_pago', 'dsar_subject_key' = 'email');
ALTER TABLE ${data_catalog}.silver.pagos ALTER COLUMN pais SET TAGS ('gov_lab_country' = 'country_code', 'gov_lab_sensitivity' = 'interno');
ALTER TABLE ${data_catalog}.silver.pagos ALTER COLUMN email SET TAGS ('gov_lab_pii' = 'email', 'gov_lab_sensitivity' = 'restringido');
ALTER TABLE ${data_catalog}.silver.pagos ALTER COLUMN email_hash SET TAGS ('gov_lab_sensitivity' = 'confidencial');

-- gold.pagos (materialized view, producto DP-01)
ALTER TABLE ${data_catalog}.gold.pagos SET TAGS ('gov_lab_domain' = 'pagos', 'gov_lab_owner' = 'randrade@labpagos.example', 'gov_lab_steward' = 'dvega@labpagos.example', 'gov_lab_sensitivity' = 'restringido', 'gov_lab_retention' = '7y', 'retention_policy' = 'RET-PAG-TRANSACC', 'retention_column' = 'fecha_pago', 'dsar_subject_key' = 'email');
ALTER TABLE ${data_catalog}.gold.pagos ALTER COLUMN pago_id SET TAGS ('gov_lab_cde' = 'CDE-01', 'gov_lab_sensitivity' = 'interno');
ALTER TABLE ${data_catalog}.gold.pagos ALTER COLUMN monto SET TAGS ('gov_lab_cde' = 'CDE-02', 'gov_lab_sensitivity' = 'confidencial');
ALTER TABLE ${data_catalog}.gold.pagos ALTER COLUMN pais SET TAGS ('gov_lab_cde' = 'CDE-03', 'gov_lab_country' = 'country_code', 'gov_lab_sensitivity' = 'interno');
ALTER TABLE ${data_catalog}.gold.pagos ALTER COLUMN email SET TAGS ('gov_lab_cde' = 'CDE-04', 'gov_lab_pii' = 'email', 'gov_lab_sensitivity' = 'restringido');
ALTER TABLE ${data_catalog}.gold.pagos ALTER COLUMN fecha_pago SET TAGS ('gov_lab_cde' = 'CDE-05', 'gov_lab_sensitivity' = 'interno');
ALTER TABLE ${data_catalog}.gold.pagos ALTER COLUMN email_hash SET TAGS ('gov_lab_sensitivity' = 'confidencial');
ALTER TABLE ${data_catalog}.gold.pagos ALTER COLUMN moneda SET TAGS ('gov_lab_sensitivity' = 'interno');
