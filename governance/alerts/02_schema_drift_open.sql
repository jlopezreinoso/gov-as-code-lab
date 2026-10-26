-- Cambios de esquema fuera de contrato sin resolver.
SELECT uc_object, change_type, column_name, detected_at
FROM ${gov_catalog}.schema_change.schema_drift_events
WHERE status = 'ABIERTO'
