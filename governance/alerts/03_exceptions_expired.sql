-- Excepciones vencidas que siguen abiertas (GOV-EXC-001).
SELECT exception_id, control_id, asset, expiration_date
FROM ${gov_catalog}.evidence.v_exceptions_expired
