-- T-12 (C-07, POL-04): reglas DQ del proyecto con FAIL en las últimas 24 horas.
SELECT r.rule_id, q.uc_object, r.pass_rate, r.evaluated_at
FROM ${gov_catalog}.quality.dq_results r
JOIN ${gov_catalog}.quality.dq_rules q ON q.rule_id = r.rule_id
WHERE q.project_id = 'PRJ-PAG-001' AND r.status = 'FAIL'
  AND r.evaluated_at >= current_timestamp() - INTERVAL 24 HOURS
