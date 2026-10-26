-- Pruebas de control cuyo último resultado no es PASS.
SELECT control_id, domain, result, executed_at
FROM ${gov_catalog}.evidence.v_control_status
WHERE result IS NOT NULL AND result <> 'PASS'
