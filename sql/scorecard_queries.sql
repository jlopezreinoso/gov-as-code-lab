-- Consultas del scorecard de gobierno (N11). Crear un AI/BI Dashboard con un dataset por consulta.
-- Reemplazar ${gov_catalog} por el catálogo del ambiente.

-- 1. Estado de controles (último resultado)
SELECT domain, result, count(*) AS controles
FROM ${gov_catalog}.evidence.v_control_status GROUP BY ALL;

-- 2. Avance de entregables por proyecto
SELECT project_id, total, completos, round(100 * completos / total, 1) AS pct
FROM ${gov_catalog}.evidence.v_deliverables_progress;

-- 3. Drift de esquema abierto por objeto
SELECT uc_object, change_type, count(*) AS eventos
FROM ${gov_catalog}.schema_change.schema_drift_events WHERE status = 'ABIERTO' GROUP BY ALL;

-- 4. Calidad: pass rate diario por regla
SELECT date(evaluated_at) AS dia, rule_id, avg(pass_rate) AS pass_rate
FROM ${gov_catalog}.quality.dq_results GROUP BY ALL;

-- 5. Excepciones vencidas
SELECT count(*) AS excepciones_vencidas FROM ${gov_catalog}.evidence.v_exceptions_expired;

-- 6. Grants a usuarios (debe ser 0)
SELECT count(*) AS grants_a_usuarios FROM ${gov_catalog}.evidence.v_grants_to_users;

-- 7. Recertificación de accesos del ciclo actual
SELECT cycle, decision, count(*) AS revisiones
FROM ${gov_catalog}.access.access_reviews GROUP BY ALL;

-- 8. Costo por cost_center (últimos 30 días)
SELECT cost_center, sum(usage_quantity) AS dbus
FROM ${gov_catalog}.evidence.v_cost_by_cost_center
WHERE usage_date >= date_sub(current_date(), 30) GROUP BY ALL;

-- 9. Settings fuera de lo esperado
SELECT setting_key, expected_value, actual_value
FROM ${gov_catalog}.platform.platform_settings_baseline WHERE compliant = false;
