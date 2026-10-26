-- Migración 0001: marca el punto de partida del catálogo (el DDL inicial lo crea gov_bootstrap).
-- Las siguientes migraciones (0002_..., 0003_...) llevan los ALTER TABLE cuando el modelo evolucione.
-- Regla: nunca editar una migración ya aplicada; crear una nueva.
ALTER CATALOG ${gov_catalog} SET TAGS ('gov_schema_version' = '0001');
