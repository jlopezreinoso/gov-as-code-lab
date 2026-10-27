# gov-as-code — Gobierno como Código en Databricks

Llena y mantiene el catálogo de gobierno (`sql/gov_catalog_ddl.sql`: 16 esquemas, 90 tablas, 8 vistas) de forma
automática. Regla: **Git es la fuente de verdad, Databricks ejecuta y las tablas de gobierno registran.**
Ninguna tabla se llena a mano en producción. El detalle por tabla está en la hoja `05_COMO_SE_CARGA` de
`CATALOGO_GOBIERNO_COMO_CODIGO_v2.xlsx`. Cómo subirlo y desplegarlo: **`docs/DESPLIEGUE.md`**.

## Jobs (Lakeflow Jobs, serverless)

| Job | Tipo | Disparador | Llena / mantiene |
|---|---|---|---|
| `gov_bootstrap` | Baseline | Manual, una vez por ambiente y por cambio de DDL | Catálogo, migraciones, propiedades (Predictive Optimization, tags de retención) y permisos por grupo |
| `gov_sync` | Baseline | CI tras cada merge | 52 tablas de definición + SQL nativo (máscaras, ABAC) + `deployment_assets`; luego corre las pruebas de control como gate |
| `gov_reconcile` | Baseline | Diario 06:00 UTC | Drift de esquema, pruebas de control, DQ custom, settings; tarea final de **alertas** |
| `gov_retention` | Baseline | Diario 03:00 UTC | Purga por política (tags `retention_policy` / `retention_column`), legal holds, VACUUM → `purge_log` |
| `gov_access_review` | Baseline | Diario 05:30 UTC | Ciclo trimestral de recertificación (`access_reviews`) y expiración de `temporary_access` |
| `gov_dsar` | PII | Cambio en `privacy.dsar_requests` | Supresión del titular (tag `dsar_subject_key`, comparación por hash) → `dsar_execution_log` |
| `gov_ai_eval` | IA / HITL | Manual o desde el CI de modelos | `validation_results`, `ai_evaluation_index` (+ run de MLflow) |
| `gov_genie_benchmarks` | GENIE / ONT | Lunes 07:00 UTC y tras cambios semánticos | `genie_benchmark_results` (falla bajo el pass rate mínimo) |
| `gov_ontology_hygiene` | ONT | Trimestral | Propuestas de deprecación en `ontology_hygiene_log` |
| `gov_itsm_sync` | Opcional | Cada 15 min (pausado por defecto) | Decisiones aprobadas en el ITSM → tablas humanas |

Más la **App `gov-review`** (Databricks App) para las decisiones humanas: revisión HITL, excepciones (con SoD:
quien solicita no aprueba), recertificación, firmas de gate e incidentes.

## Permisos (separación de funciones)

`gov_grants` aplica, desde `governance_soft/platform/table_writers.yaml`:
- `grp-gov-deployers` (CI): MODIFY solo en tablas de definición.
- `grp-gov-runners` (jobs y pipelines): MODIFY solo en resultados y eventos.
- `grp-gov-app` (App/ITSM): MODIFY solo en tablas de decisiones humanas.
- `grp-gov-readers`: lectura. `grp-gov-auditors`: `evidence` + READ METADATA.

## Estructura

```text
gov-as-code/
├── databricks.yml                 # bundle: variables, grupos, targets dev / prd
├── resources/gov_jobs.yml         # 10 jobs
├── resources/gov_app.yml          # App de decisiones humanas
├── apps/gov_review/               # código de la App (Streamlit)
├── sql/gov_catalog_ddl.sql        # DDL del catálogo (idempotente)
├── sql/migrations/                # NNNN_descripcion.sql, una vez cada una
├── sql/gov_table_properties.sql   # Predictive Optimization + tags de retención
├── sql/scorecard_queries.sql      # consultas para el dashboard de scorecard
├── governance_soft/                    # LO QUE ESCRIBEN LAS PERSONAS (revisado por PR)
│   ├── policies/ tags/ controls/ contracts/ dq_rules/ registry/
│   ├── masks/ abac/               # implementación nativa
│   ├── tests/                     # pruebas de control (devuelven violaciones)
│   ├── alerts/                    # alertas (devuelven filas que requieren atención)
│   └── platform/                  # settings esperados, mapa ITSM, quién escribe cada tabla
├── src/                           # gov_specs (puro) · gov_lib · gov_sync · gov_reconcile · gov_alerts · gov_grants
│                                  # gov_retention · gov_access_review · gov_dsar · gov_ai_eval · gov_genie_benchmarks
│                                  # gov_ontology_hygiene · gov_itsm_sync · run_sql_file
├── tests/                         # pytest (sin Spark)
├── docs/DESPLIEGUE.md · docs/RUNBOOK.md
└── .github/workflows/gov-as-code.yml
```

## Desde un pipeline del proyecto

```python
from gov_lib import Gov
gov = Gov(spark, "gov_prd")
run_id = gov.start_run("PRJ-VENTAS", "job_ventas_diario", git_commit="abc123")
gov.log_quarantine("ventas_prd.silver.pedidos", "ventas_prd.silver.pedidos_quarantine", "monto negativo", 12)
gov.end_run(run_id, "SUCCESS", records_in=1000, records_out=988)
```

El SP del pipeline debe ser miembro de `grp-gov-runners`.

## Validar antes de PROD

- Sintaxis de `CREATE POLICY` (ABAC) y de `ALTER CATALOG ... ENABLE PREDICTIVE OPTIMIZATION`.
- Keys de la Workspace Conf API (`settings.yaml`) y mapeo del ITSM.
- `environment_version` de serverless, sintaxis de `apps` y `trigger.table_update` en tu versión del CLI.
- Métodos del SDK de Genie (`w.genie.start_conversation_and_wait`).
- Columnas de las system tables usadas en tests, alertas y vistas (`inherited_from`, `table_tags`, `table_lineage`).
- Fijar la versión de `databricks/setup-cli` en el workflow.

## No incluido

- Terraform (no es necesario: todo se despliega con Bundles, SQL y SDK; la infraestructura base del cloud se
  configura una vez y `gov_reconcile` la verifica).
- Dashboard AI/BI como archivo: se crea desde `sql/scorecard_queries.sql`.
- Jobs propios de cada proyecto (ingesta, transformación): se instrumentan con `gov_lib`.
