-- POL-02 / matriz 13.1: consumidores del producto DP-01. Solo grupos (SEC-01). Lo que cada uno VE lo deciden las
-- políticas ABAC (país y PII), no estos grants. g_gov_lab_noaccess no recibe nada (prueba negativa de G5).
GRANT USE CATALOG ON CATALOG ${data_catalog} TO `g_gov_lab_ec`;
GRANT USE CATALOG ON CATALOG ${data_catalog} TO `g_gov_lab_pe`;
GRANT USE CATALOG ON CATALOG ${data_catalog} TO `g_gov_lab_pii`;
GRANT USE SCHEMA ON SCHEMA ${data_catalog}.gold TO `g_gov_lab_ec`;
GRANT USE SCHEMA ON SCHEMA ${data_catalog}.gold TO `g_gov_lab_pe`;
GRANT USE SCHEMA ON SCHEMA ${data_catalog}.gold TO `g_gov_lab_pii`;
GRANT SELECT ON TABLE ${data_catalog}.gold.pagos TO `g_gov_lab_ec`;
GRANT SELECT ON TABLE ${data_catalog}.gold.pagos TO `g_gov_lab_pe`;
GRANT SELECT ON TABLE ${data_catalog}.gold.pagos TO `g_gov_lab_pii`;
