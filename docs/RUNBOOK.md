# Runbook del catálogo de gobierno

| Síntoma | Causa probable | Acción | Evidencia |
|---|---|---|---|
| `gov_sync` falla en "Especificaciones inválidas" | YAML con campos faltantes, versión no semver, tabla no registrable | Corregir el YAML indicado en el mensaje; el CI lo detecta antes con `--dry-run` | Log del job |
| `gov_sync` falla en un SQL de `abac/` o `masks/` | Sintaxis no soportada en el runtime o falta de permisos del SP | Probar el SQL en DEV; dar al SP `MANAGE` sobre el catálogo de datos | Log del job |
| `gov_sync` falla en `MERGE ... columnas inexistentes` | El YAML usa una columna que el DDL no tiene | Corregir el YAML o crear una migración | Log del job |
| Tarea `control_tests` en rojo tras un deploy | Un control no se cumple en el ambiente | Ver `evidence.v_control_status`; corregir o pedir excepción en la App | `control_test_results` |
| `gov_reconcile.alerts` en rojo | Hay alertas activas (drift, excepciones vencidas, grants a usuarios…) | Atender cada alerta listada en el log; no es una falla técnica | `governance/alerts/*.sql` |
| `gov_reconcile` falla en `settings` | Key inexistente en la Workspace Conf API | Corregir `governance/platform/settings.yaml` | Log del job |
| `gov_retention` reporta "política o retention_column no definidas" | Tabla con tag `retention_policy` sin su par o sin política registrada | Completar tags o el registro `privacy.retention_policies` | `purge_log` |
| `gov_dsar` deja estado REVISAR | Quedan filas del titular (tabla sin tag `dsar_subject_key` o clave distinta) | Etiquetar la tabla y reejecutar; VACUUM lo cierra `gov_retention` | `dsar_execution_log` |
| `gov_access_review --mode expire` en rojo | Accesos temporales vencidos sin revocar | Revocar vía PR de grants o ejecutar con `--revoke` | `temporary_access` |
| `gov_genie_benchmarks` bajo el mínimo | Un cambio semántico empeoró respuestas | No promover; revisar Metric View, Knowledge Store o instrucciones | `genie_benchmark_results` |
| `gov_ai_eval` RECHAZADO | Exactitud bajo el umbral | No promover el modelo/agente | `ai_evaluation_index` |
| La App no escribe | SP de la App sin MODIFY o warehouse sin `CAN_USE` | Reejecutar `gov_bootstrap.grants`; revisar recurso del warehouse | Audit log |
| Cambio manual detectado en PROD | Alguien modificó sin PR | Revertir, registrar incidente, reforzar permisos (GOV-DEV-001) | `system.access.audit` |

## Reprocesar

Todos los jobs son idempotentes (MERGE por clave y ids deterministas): reejecutar no duplica datos.

## Reglas

- Nunca escribir a mano en las tablas de gobierno de PROD.
- Nunca editar una migración ya aplicada: crear una nueva.
- Los secretos solo en secret scopes o en los secretos de GitHub; nunca en Git.
