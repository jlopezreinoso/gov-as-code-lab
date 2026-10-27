-- T-09 (C-08, SEC-08): REPORTE mensual (no es prueba automática): quién leyó gold.pagos en los últimos 30 días.
-- Lo revisa Security y lo firma en la recertificación; cruzar con miembros de g_gov_lab_pii.
SELECT event_date, user_identity.email AS principal, action_name,
       request_params.full_name_arg AS objeto, count(*) AS eventos
FROM system.access.audit
WHERE service_name = 'unityCatalog'
  AND request_params.full_name_arg = '${data_catalog}.gold.pagos'
  AND event_date >= current_date() - INTERVAL 30 DAYS
GROUP BY ALL
ORDER BY event_date DESC
