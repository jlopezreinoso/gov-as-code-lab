# Pruebas manuales de control (automated: false)

Evidencia que no se obtiene con SQL. Cada una se ejecuta con la CLI (solo lectura) y su resultado se anota en la bitácora del expediente.

| Test | Control | Cómo se verifica | Esperado |
|---|---|---|---|
| T-02 | C-02 aislamiento | `databricks catalogs get gov_manual_lab` y `databricks workspace-bindings get-bindings catalog gov_manual_lab` | `isolation_mode = ISOLATED`; solo el workspace dev |
| T-06 | C-06 ETL solo por SP | `databricks groups get <id g_gov_lab_etl>` | Un único miembro: `sp_etl_pagos` (ServicePrincipals) |
| T-10 | C-11 gobierno como código | `git log` del repo + `databricks policies list-policies CATALOG gov_manual_lab` | Cada política y función del catálogo existe en `governance_soft/` |
| T-15 | C-12 recertificación | Ejecución trimestral de `gov_access_review` + firma del Data Owner | 100 % de miembros de `g_gov_lab_pii`, `g_gov_lab_ec` y `g_gov_lab_pe` revisados |
