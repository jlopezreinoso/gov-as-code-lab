-- Propiedades del catálogo de gobierno (tarea de gov_bootstrap, idempotente).
-- 1) Mantenimiento físico nativo (OPTIMIZE/VACUUM automáticos): sin job propio.
ALTER CATALOG ${gov_catalog} ENABLE PREDICTIVE OPTIMIZATION;

-- 2) Retención de las tablas de EVENTOS del propio catálogo, gestionada por gov_retention mediante tags nativos.
--    Las tablas de definición y decisiones no se purgan (son evidencia de auditoría).
--    Si 'retention_policy' es un governed tag con valores permitidos, agregar RET-GOV-EVENTS a esa lista.
ALTER TABLE ${gov_catalog}.risk_control.control_test_results SET TAGS ('retention_policy' = 'RET-GOV-EVENTS', 'retention_column' = 'created_at');
ALTER TABLE ${gov_catalog}.quality.dq_results SET TAGS ('retention_policy' = 'RET-GOV-EVENTS', 'retention_column' = 'created_at');
ALTER TABLE ${gov_catalog}.schema_change.schema_snapshots SET TAGS ('retention_policy' = 'RET-GOV-EVENTS', 'retention_column' = 'created_at');
ALTER TABLE ${gov_catalog}.processing.processing_runs SET TAGS ('retention_policy' = 'RET-GOV-EVENTS', 'retention_column' = 'created_at');
ALTER TABLE ${gov_catalog}.processing.processing_errors SET TAGS ('retention_policy' = 'RET-GOV-EVENTS', 'retention_column' = 'created_at');
ALTER TABLE ${gov_catalog}.semantic.genie_benchmark_results SET TAGS ('retention_policy' = 'RET-GOV-EVENTS', 'retention_column' = 'created_at');

-- 3) Metadata de gobierno del propio catálogo.
ALTER CATALOG ${gov_catalog} SET TAGS ('data_layer' = 'control_plane', 'cost_center' = 'CC-GOV-001');
