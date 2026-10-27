# Cómo subir y desplegar gov-as-code

Hay dos destinos: **GitHub** (donde vive el código y corre el CI) y **Databricks** (donde corren los jobs).
Lo recomendado es subir a GitHub y dejar que el CI despliegue en Databricks. También puedes desplegar
manualmente desde tu computador la primera vez.

## 0. Requisitos (una sola vez)

| Qué | Dónde |
|---|---|
| Git y una cuenta/organización de GitHub (o Azure DevOps / GitLab, adaptando el workflow) | Tu equipo |
| Databricks CLI ≥ 0.250 (`winget install Databricks.DatabricksCLI` o la guía oficial) | Tu equipo |
| Python 3.11 + `pip install -r requirements-dev.txt` | Tu equipo |
| Workspaces DEV y PRD con Unity Catalog y serverless habilitado | Databricks |
| Un SQL warehouse (para la App) | Databricks |
| Grupos de cuenta: `grp-gov-admins`, `grp-gov-deployers`, `grp-gov-runners`, `grp-gov-app`, `grp-gov-readers`, `grp-gov-auditors` | Account console / IdP (SCIM) |
| Service principal de despliegue por ambiente, con OAuth secret, miembro de `grp-gov-deployers` y `grp-gov-runners`, con permiso para crear catálogos | Account console |
| Service principal de la App, miembro de `grp-gov-app` (lo crea Databricks al desplegar la App) | Automático |

## 1. Ajustar la configuración

1. `databricks.yml`: reemplazar los dos `host`, el `warehouse_id` y, si cambian, los nombres de grupos y catálogos.
2. `governance_soft/registry/*.yaml`, `policies/`, `controls/`, `contracts/`: reemplazar los ejemplos por los de tu proyecto.
3. `governance_soft/platform/settings.yaml`: validar los nombres de las keys en tu workspace.
4. `resources/gov_jobs.yml`: borrar los jobs condicionales que tu proyecto no use (ver el comentario inicial).
5. Validar localmente:

```bash
pip install -r requirements-dev.txt
pytest -q
python src/gov_sync.py --root . --gov-catalog gov_dev --data-catalog ventas_dev --env dev --dry-run
```

## 2. Subir a GitHub

```bash
cd gov-as-code
git init -b main          # si no está inicializado
git add .
git commit -m "gov-as-code: catálogo, jobs, App y CI de gobierno"
git remote add origin https://github.com/<organizacion>/gov-as-code.git
git push -u origin main
```

Luego, en GitHub → **Settings → Environments**:

- `dev`: secretos `DATABRICKS_HOST`, `DATABRICKS_CLIENT_ID`, `DATABRICKS_CLIENT_SECRET` (SP de DEV).
- `prd`: los mismos secretos del SP de PRD y **Required reviewers** (otra persona aprueba: SoD).
- **Settings → Branches**: proteger `main` (PR obligatorio + 1 aprobación + checks verdes).

Desde ese momento: cada PR valida; cada merge despliega DEV, ejecuta `gov_sync` y espera aprobación para PRD.

## 3. Primer despliegue en Databricks (bootstrap)

El CI no crea el catálogo por sí solo la primera vez. Ejecutar una vez por ambiente (desde tu equipo con
`databricks auth login`, o agregando el paso al workflow):

```bash
databricks bundle validate -t dev
databricks bundle deploy -t dev
databricks bundle run gov_bootstrap -t dev     # catálogo, migraciones, propiedades y permisos
databricks bundle run gov_sync -t dev          # carga las definiciones de governance_soft/
databricks bundle run gov_reconcile -t dev     # primera conciliación + alertas
```

Repetir con `-t prd` (con el SP de PRD). Verificación rápida en un SQL editor:

```sql
SHOW SCHEMAS IN gov_dev;                                   -- 16 esquemas
SELECT * FROM gov_dev.org.policies;                        -- POL-SEC-003
SELECT * FROM gov_dev.evidence.v_control_status;           -- resultado de las pruebas
```

## 4. Operación diaria

| Quiero… | Hago… |
|---|---|
| Crear o cambiar una política, control, contrato, regla DQ o registro | Editar el YAML, abrir PR, merge |
| Revisar resultados | `evidence.*`, dashboard de scorecard (`sql/scorecard_queries.sql`) |
| Registrar una decisión humana | App `gov-review-<ambiente>` (o el ITSM con `gov_itsm_sync`) |
| Cambiar el modelo de tablas | Nueva migración `sql/migrations/NNNN_descripcion.sql` + PR |
| Instrumentar un pipeline del proyecto | `from gov_lib import Gov` (ver README) |

Si algo falla, ver `docs/RUNBOOK.md`.
