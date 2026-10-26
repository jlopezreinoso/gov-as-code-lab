-- Reglas de calidad custom con FAIL en las últimas 24 horas.
SELECT r.rule_id, q.uc_object, r.pass_rate, r.evaluated_at
FROM ${gov_catalog}.quality.dq_results r
JOIN ${gov_catalog}.quality.dq_rules q ON q.rule_id = r.rule_id
WHERE r.status = 'FAIL' AND r.evaluated_at >= current_timestamp() - INTERVAL 24 HOURS
