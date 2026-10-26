-- Revisiones humanas (HITL) vencidas según su SLA.
SELECT review_id, uc_object, field, assigned_to, sla_due_at
FROM ${gov_catalog}.review.review_queue
WHERE status = 'PENDIENTE' AND sla_due_at < current_timestamp()
