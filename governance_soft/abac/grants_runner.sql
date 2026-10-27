-- POL-02 / C-01..C-10: el runner (g_gov_lab_etl = sp_etl_pagos) necesita VER los metadatos de todo el catálogo de datos
-- para que los tests de gov_reconcile sobre information_schema no den PASS falso por objetos invisibles.
-- BROWSE = metadatos sin acceso a datos. Idempotente.
GRANT BROWSE ON CATALOG ${data_catalog} TO `g_gov_lab_etl`;
