-- POL-02 / matriz 13: privilegios del runner (g_gov_lab_etl = sp_etl_pagos) en el catálogo de datos. Idempotente.
-- BROWSE: los tests de gov_reconcile sobre information_schema ven todos los objetos (evita PASS falso).
GRANT BROWSE ON CATALOG ${data_catalog} TO `g_gov_lab_etl`;
-- Pipeline DP-01 (lab_pagos_medallion): leer el landing y publicar bronze/silver/gold (el SP queda como owner).
GRANT READ VOLUME ON VOLUME ${data_catalog}.bronze.landing TO `g_gov_lab_etl`;
-- H-18b: gov_retention (runner) borra los archivos del landing con más de 30 días (RET-PAG-LANDING).
GRANT WRITE VOLUME ON VOLUME ${data_catalog}.bronze.landing TO `g_gov_lab_etl`;
GRANT USE SCHEMA, CREATE TABLE, CREATE MATERIALIZED VIEW ON SCHEMA ${data_catalog}.bronze TO `g_gov_lab_etl`;
GRANT USE SCHEMA, CREATE TABLE, CREATE MATERIALIZED VIEW ON SCHEMA ${data_catalog}.silver TO `g_gov_lab_etl`;
GRANT USE SCHEMA, CREATE TABLE, CREATE MATERIALIZED VIEW ON SCHEMA ${data_catalog}.gold TO `g_gov_lab_etl`;
