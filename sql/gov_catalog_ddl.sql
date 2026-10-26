-- =====================================================================
-- Catálogo de Gobierno como Código — Databricks Unity Catalog
-- Generado desde el framework GUIA_360 v4 / CHECKLIST_CONFIGURADOR v3.
-- Uso: reemplazar ${gov_catalog} (p. ej. gov_dev, gov_prd) y ${owner_group}; ejecutar con un SP de despliegue.
-- Principio: no se crean tablas para lo que Unity Catalog ya resuelve (ver hoja 04_NO_CREAR del Excel).
-- Las tablas no usadas por un proyecto quedan vacías; su uso depende de 'gov.activation'.
-- =====================================================================

CREATE CATALOG IF NOT EXISTS ${gov_catalog} COMMENT 'Catálogo de gobierno como código (control plane)';
ALTER CATALOG ${gov_catalog} OWNER TO `${owner_group}`;

-- ---------------------------------------------------------------- org
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.org COMMENT 'Organización y accountability: proyectos, dominios, roles, RACI, políticas, estándares y decisiones.';

CREATE TABLE IF NOT EXISTS ${gov_catalog}.org.projects (
  project_id STRING NOT NULL,
  name STRING,
  domain_id STRING,
  criticality_level INT,
  cloud STRING,
  status STRING,
  business_owner STRING,
  data_owner STRING,
  sponsor STRING,
  start_date DATE,
  charter_uri STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_projects PRIMARY KEY (project_id)
)
COMMENT 'Proyectos gobernados y su configuración principal.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '01, configurador', 'gov.writer' = 'Gov Lead');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.org.project_features (
  project_id STRING NOT NULL,
  feature_code STRING NOT NULL,
  enabled BOOLEAN,
  justification STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_project_features PRIMARY KEY (project_id, feature_code)
)
COMMENT 'Características activadas por proyecto (códigos del configurador).'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '1_CONFIGURADOR', 'gov.writer' = 'Gov Lead');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.org.domains (
  domain_id STRING NOT NULL,
  name STRING,
  parent_domain_id STRING,
  purpose STRING,
  governed_tag STRING,
  business_owner STRING,
  technical_owner STRING,
  criticality STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_domains PRIMARY KEY (domain_id)
)
COMMENT 'Dominios y subdominios corporativos.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'P06, 04', 'gov.writer' = 'Data Architect');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.org.roles (
  role_code STRING NOT NULL,
  name STRING,
  description STRING,
  responsibilities STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_roles PRIMARY KEY (role_code)
)
COMMENT 'Catálogo de roles de gobierno.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'P07', 'gov.writer' = 'Gov Lead');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.org.role_assignments (
  assignment_id STRING NOT NULL,
  project_id STRING,
  domain_id STRING,
  role_code STRING,
  principal STRING,
  principal_type STRING,
  start_date DATE,
  end_date DATE,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_role_assignments PRIMARY KEY (assignment_id)
)
COMMENT 'Persona o grupo asignado a cada rol por proyecto/dominio.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '03, P07', 'gov.writer' = 'Gov Lead');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.org.raci_matrix (
  project_id STRING NOT NULL,
  activity_id STRING NOT NULL,
  role_code STRING NOT NULL,
  activity STRING,
  raci STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_raci_matrix PRIMARY KEY (project_id, activity_id, role_code)
)
COMMENT 'RACI por actividad y rol (una sola A por actividad).'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '03', 'gov.writer' = 'Gov Lead');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.org.policies (
  policy_id STRING NOT NULL,
  version STRING NOT NULL,
  name STRING,
  category STRING,
  owner STRING,
  approved_by STRING,
  effective_from DATE,
  review_date DATE,
  status STRING,
  document_uri STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_policies PRIMARY KEY (policy_id, version)
)
COMMENT 'Catálogo de políticas aprobadas y sus versiones.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'P04', 'gov.writer' = 'Gov Architect');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.org.standards (
  standard_id STRING NOT NULL,
  version STRING NOT NULL,
  name STRING,
  standard_type STRING,
  rule_expression STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_standards PRIMARY KEY (standard_id, version)
)
COMMENT 'Estándares de naming, modelado, tags y documentación.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'P05, N06', 'gov.writer' = 'Gov Architect');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.org.business_decisions (
  decision_id STRING NOT NULL,
  project_id STRING,
  name STRING,
  business_question STRING,
  owner STRING,
  consumer STRING,
  impact_if_wrong STRING,
  automation_level STRING,
  human_approval_required BOOLEAN,
  criticality STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_business_decisions PRIMARY KEY (decision_id)
)
COMMENT 'Decisiones de negocio que el proyecto soporta.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '02', 'gov.writer' = 'Domain SME');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.org.council_decisions (
  decision_id STRING NOT NULL,
  decision_date DATE,
  topic STRING,
  decision STRING,
  rationale STRING,
  approvers STRING,
  related_ids STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_council_decisions PRIMARY KEY (decision_id)
)
COMMENT 'Actas y decisiones del Data Council.'
TBLPROPERTIES ('gov.activation' = 'BASE@2', 'gov.reference' = 'P03, GOV-ORG-004', 'gov.writer' = 'Gov Lead');

-- ---------------------------------------------------------------- inventory
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.inventory COMMENT 'Inventario funcional: fuentes, productos, CDE, glosario y contratos (solo atributos que Unity Catalog no guarda).';

CREATE TABLE IF NOT EXISTS ${gov_catalog}.inventory.data_sources (
  source_id STRING NOT NULL,
  project_id STRING,
  name STRING,
  source_type STRING,
  source_system STRING,
  domain_id STRING,
  owner STRING,
  steward STRING,
  authoritative BOOLEAN,
  connection_type STRING,
  cdc_available BOOLEAN,
  contains_pii BOOLEAN,
  classification STRING,
  frequency STRING,
  sla STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_data_sources PRIMARY KEY (source_id)
)
COMMENT 'Inventario de fuentes de datos.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '05', 'gov.writer' = 'Data Engineer');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.inventory.data_products (
  product_id STRING NOT NULL,
  project_id STRING,
  domain_id STRING,
  name STRING,
  purpose STRING,
  owner STRING,
  steward STRING,
  gold_object STRING,
  grain STRING,
  refresh STRING,
  sla STRING,
  lifecycle_status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_data_products PRIMARY KEY (product_id)
)
COMMENT 'Catálogo de productos de datos.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '09', 'gov.writer' = 'Data Architect');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.inventory.asset_business_attributes (
  uc_object STRING NOT NULL,
  project_id STRING,
  product_id STRING,
  criticality STRING,
  sla STRING,
  consumers STRING,
  notes STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_asset_business_attributes PRIMARY KEY (uc_object)
)
COMMENT 'Atributos de negocio de objetos UC que no existen como metadata nativa.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '06', 'gov.writer' = 'Data Steward');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.inventory.cde_registry (
  cde_id STRING NOT NULL,
  project_id STRING,
  product_id STRING,
  uc_object STRING,
  column_name STRING,
  business_term_id STRING,
  decision_id STRING,
  criticality STRING,
  owner STRING,
  steward STRING,
  dq_required BOOLEAN,
  certification_required BOOLEAN,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_cde_registry PRIMARY KEY (cde_id)
)
COMMENT 'Elementos críticos de datos (CDE).'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '07', 'gov.writer' = 'Data Steward');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.inventory.business_glossary (
  term_id STRING NOT NULL,
  domain_id STRING,
  term STRING,
  definition STRING,
  synonyms STRING,
  formula STRING,
  unit STRING,
  owner STRING,
  steward STRING,
  status STRING,
  effective_from DATE,
  deprecated_at DATE,
  page_ref STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_business_glossary PRIMARY KEY (term_id)
)
COMMENT 'Glosario de negocio (si se usan Pages, guarda la referencia).'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '08, P08', 'gov.writer' = 'Data Steward');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.inventory.data_contracts (
  contract_id STRING NOT NULL,
  version STRING NOT NULL,
  product_id STRING,
  uc_object STRING,
  status STRING,
  yaml_uri STRING,
  git_commit STRING,
  compatibility STRING,
  approved_by STRING,
  effective_from DATE,
  deprecated_at DATE,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_data_contracts PRIMARY KEY (contract_id, version)
)
COMMENT 'Contratos de datos versionados (el YAML vive en Git).'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '10, N21', 'gov.writer' = 'Data Engineer');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.inventory.contract_columns (
  contract_id STRING NOT NULL,
  version STRING NOT NULL,
  column_name STRING NOT NULL,
  data_type STRING,
  nullable BOOLEAN,
  allowed_values STRING,
  classification STRING,
  is_key BOOLEAN,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_contract_columns PRIMARY KEY (contract_id, version, column_name)
)
COMMENT 'Esquema contratado por versión (base de la detección de drift).'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '10, GOV-SCH-005', 'gov.writer' = 'Data Engineer');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.inventory.master_entities (
  entity_id STRING NOT NULL,
  domain_id STRING,
  golden_source_object STRING,
  match_rules_uri STRING,
  survivorship_rules_uri STRING,
  owner STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_master_entities PRIMARY KEY (entity_id)
)
COMMENT 'Entidades maestras y sus reglas de golden record.'
TBLPROPERTIES ('gov.activation' = 'MDM', 'gov.reference' = 'N05', 'gov.writer' = 'Data Architect');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.inventory.reference_code_lists (
  list_id STRING NOT NULL,
  code STRING NOT NULL,
  version STRING NOT NULL,
  description STRING,
  valid_from DATE,
  valid_to DATE,
  owner STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_reference_code_lists PRIMARY KEY (list_id, code, version)
)
COMMENT 'Listas de códigos de referencia versionadas.'
TBLPROPERTIES ('gov.activation' = 'MDM', 'gov.reference' = 'N05, GOV-MDM-002', 'gov.writer' = 'Data Steward');

-- ---------------------------------------------------------------- risk_control
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.risk_control COMMENT 'Riesgo → control → prueba → evidencia: el núcleo del gobierno como código.';

CREATE TABLE IF NOT EXISTS ${gov_catalog}.risk_control.risk_register (
  risk_id STRING NOT NULL,
  project_id STRING,
  domain_id STRING,
  asset STRING,
  description STRING,
  cause STRING,
  impact STRING,
  likelihood INT,
  impact_score INT,
  inherent_score INT,
  owner STRING,
  treatment STRING,
  residual_score INT,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_risk_register PRIMARY KEY (risk_id)
)
COMMENT 'Registro de riesgos de gobierno.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '16', 'gov.writer' = 'Gov Architect');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.risk_control.controls (
  control_id STRING NOT NULL,
  project_id STRING,
  risk_id STRING,
  policy_id STRING,
  domain STRING,
  question STRING,
  description STRING,
  control_type STRING,
  native_or_custom STRING,
  databricks_capability STRING,
  custom_object STRING,
  evidence STRING,
  owner STRING,
  frequency STRING,
  failure_action STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_controls PRIMARY KEY (control_id)
)
COMMENT 'Matriz de controles (precargable con los controles del configurador).'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '17, 06_MATRIZ_CONTROLES', 'gov.writer' = 'Gov Architect');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.risk_control.control_tests (
  test_id STRING NOT NULL,
  control_id STRING,
  description STRING,
  expected STRING,
  automated BOOLEAN,
  query_or_script_uri STRING,
  environment STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_control_tests PRIMARY KEY (test_id)
)
COMMENT 'Pruebas de aceptación de cada control.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '25', 'gov.writer' = 'QA');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.risk_control.control_test_results (
  result_id STRING NOT NULL,
  test_id STRING,
  run_id STRING,
  executed_at TIMESTAMP,
  result STRING,
  evidence_uri STRING,
  details STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_control_test_results PRIMARY KEY (result_id)
)
COMMENT 'Resultados de ejecución de las pruebas de control.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '25, N18', 'gov.writer' = 'CI/CD (service principal)');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.risk_control.native_vs_custom (
  requirement_id STRING NOT NULL,
  project_id STRING,
  requirement STRING,
  native_capability STRING,
  available STRING,
  coverage STRING,
  gap STRING,
  decision STRING,
  adr_id STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_native_vs_custom PRIMARY KEY (requirement_id)
)
COMMENT 'Decisión nativo vs custom por requerimiento.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '18', 'gov.writer' = 'Gov Architect');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.risk_control.exceptions (
  exception_id STRING NOT NULL,
  control_id STRING,
  asset STRING,
  reason STRING,
  requested_by STRING,
  approved_by STRING,
  compensating_control STRING,
  start_date DATE,
  expiration_date DATE,
  residual_risk STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_exceptions PRIMARY KEY (exception_id)
)
COMMENT 'Excepciones a controles con vencimiento.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'N09, GOV-EXC-001', 'gov.writer' = 'Gov Architect');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.risk_control.adr_log (
  adr_id STRING NOT NULL,
  project_id STRING,
  title STRING,
  context STRING,
  decision STRING,
  alternatives STRING,
  consequences STRING,
  status STRING,
  approvers STRING,
  decided_at DATE,
  git_uri STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_adr_log PRIMARY KEY (adr_id)
)
COMMENT 'Architecture Decision Records.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'N10', 'gov.writer' = 'Gov Architect');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.risk_control.deliverables_status (
  project_id STRING NOT NULL,
  deliverable_id STRING NOT NULL,
  status STRING,
  owner STRING,
  location_uri STRING,
  approved_by STRING,
  approved_at TIMESTAMP,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_deliverables_status PRIMARY KEY (project_id, deliverable_id)
)
COMMENT 'Estado de cada entregable por proyecto.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'R1 del configurador', 'gov.writer' = 'Gov Lead');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.risk_control.golive_checklist (
  project_id STRING NOT NULL,
  item_id STRING NOT NULL,
  category STRING,
  status STRING,
  evidence_uri STRING,
  owner STRING,
  verified_at TIMESTAMP,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_golive_checklist PRIMARY KEY (project_id, item_id)
)
COMMENT 'Evidencias de salida a producción por proyecto.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'R5, N18', 'gov.writer' = 'QA');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.risk_control.gate_signoffs (
  project_id STRING NOT NULL,
  gate STRING NOT NULL,
  role STRING NOT NULL,
  approver STRING,
  decision STRING,
  signed_at TIMESTAMP,
  comments STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_gate_signoffs PRIMARY KEY (project_id, gate, role)
)
COMMENT 'Aprobaciones de cada gate (G0–G7).'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '08_GATES, N18', 'gov.writer' = 'Gov Lead');

-- ---------------------------------------------------------------- quality
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.quality COMMENT 'Calidad de datos de negocio (las expectations nativas quedan en el event log de Lakeflow).';

CREATE TABLE IF NOT EXISTS ${gov_catalog}.quality.dq_rules (
  rule_id STRING NOT NULL,
  project_id STRING,
  cde_id STRING,
  uc_object STRING,
  column_name STRING,
  dimension STRING,
  engine STRING,
  expression STRING,
  severity STRING,
  threshold DOUBLE,
  failure_action STRING,
  owner STRING,
  enabled BOOLEAN,
  effective_from DATE,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_dq_rules PRIMARY KEY (rule_id)
)
COMMENT 'Catálogo de reglas de calidad y su motor de ejecución.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '15', 'gov.writer' = 'Data Steward');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.quality.dq_results (
  result_id STRING NOT NULL,
  rule_id STRING,
  run_id STRING,
  evaluated_at TIMESTAMP,
  records_checked BIGINT,
  records_failed BIGINT,
  pass_rate DOUBLE,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_dq_results PRIMARY KEY (result_id)
)
COMMENT 'Resultados de reglas custom/semánticas (no duplicar expectations nativas).'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '15', 'gov.writer' = 'Pipeline (service principal)');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.quality.dq_issues (
  issue_id STRING NOT NULL,
  rule_id STRING,
  asset STRING,
  severity STRING,
  detected_at TIMESTAMP,
  root_cause STRING,
  action STRING,
  owner STRING,
  status STRING,
  resolved_at TIMESTAMP,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_dq_issues PRIMARY KEY (issue_id)
)
COMMENT 'Issues de calidad con causa raíz.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'N15, GOV-DQ-006', 'gov.writer' = 'Data Steward');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.quality.quarantine_registry (
  quarantine_id STRING NOT NULL,
  uc_object STRING,
  quarantine_table STRING,
  reason STRING,
  records BIGINT,
  detected_at TIMESTAMP,
  reviewer STRING,
  decision STRING,
  released_at TIMESTAMP,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_quarantine_registry PRIMARY KEY (quarantine_id)
)
COMMENT 'Registro de cuarentenas (los datos rechazados viven en su dominio).'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'GOV-DQ-004', 'gov.writer' = 'Pipeline (service principal)');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.quality.reconciliation_results (
  recon_id STRING NOT NULL,
  project_id STRING,
  source STRING,
  target STRING,
  metric STRING,
  window_start TIMESTAMP,
  window_end TIMESTAMP,
  source_value DOUBLE,
  target_value DOUBLE,
  difference DOUBLE,
  tolerance DOUBLE,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_reconciliation_results PRIMARY KEY (recon_id)
)
COMMENT 'Reconciliación origen vs destino de KPIs y CDC.'
TBLPROPERTIES ('gov.activation' = 'BASE@3;CDC', 'gov.reference' = 'GOV-DQ-005, GOV-CDC-003', 'gov.writer' = 'Job de reconciliación');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.quality.acceptance_checks (
  check_id STRING NOT NULL,
  project_id STRING,
  name STRING,
  invariant_sql STRING,
  severity STRING,
  last_run TIMESTAMP,
  last_result STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_acceptance_checks PRIMARY KEY (check_id)
)
COMMENT 'Invariantes de negocio que deben cumplirse siempre.'
TBLPROPERTIES ('gov.activation' = 'BASE@2', 'gov.reference' = 'Patrón Cordillera, 25', 'gov.writer' = 'Data Engineer');

-- ---------------------------------------------------------------- schema_change
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.schema_change COMMENT 'Control de cambios de esquema, CDC y CDF.';

CREATE TABLE IF NOT EXISTS ${gov_catalog}.schema_change.schema_snapshots (
  uc_object STRING NOT NULL,
  captured_at TIMESTAMP NOT NULL,
  columns_json STRING,
  contract_id STRING,
  contract_version STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_schema_snapshots PRIMARY KEY (uc_object, captured_at)
)
COMMENT 'Fotos del esquema real para comparar contra el contrato.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'GOV-SCH-005', 'gov.writer' = 'Job de drift');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.schema_change.schema_drift_events (
  event_id STRING NOT NULL,
  uc_object STRING,
  detected_at TIMESTAMP,
  change_type STRING,
  column_name STRING,
  contract_version STRING,
  action STRING,
  approved_by STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_schema_drift_events PRIMARY KEY (event_id)
)
COMMENT 'Cambios de esquema detectados y su tratamiento.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'N21, GOV-SCH-005/006', 'gov.writer' = 'Job de drift');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.schema_change.cdc_registry (
  cdc_id STRING NOT NULL,
  source_id STRING,
  target_object STRING,
  method STRING,
  sequence_by STRING,
  delete_handling STRING,
  scd_type STRING,
  lag_slo_minutes INT,
  owner STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_cdc_registry PRIMARY KEY (cdc_id)
)
COMMENT 'Fuentes CDC: método, secuencia, deletes y SCD.'
TBLPROPERTIES ('gov.activation' = 'CDC', 'gov.reference' = 'N22', 'gov.writer' = 'Data Engineer');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.schema_change.cdf_consumers (
  uc_object STRING NOT NULL,
  consumer STRING NOT NULL,
  purpose STRING,
  cdf_mode STRING,
  retention_days INT,
  approved_by STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_cdf_consumers PRIMARY KEY (uc_object, consumer)
)
COMMENT 'Consumidores de Change Data Feed (por tabla o automático).'
TBLPROPERTIES ('gov.activation' = 'CDF', 'gov.reference' = 'N22, GOV-CDF-001/005', 'gov.writer' = 'Data Owner');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.schema_change.streaming_registry (
  stream_id STRING NOT NULL,
  source STRING,
  target STRING,
  checkpoint_location STRING,
  schema_tracking_location STRING,
  latency_slo_seconds INT,
  replay_procedure_uri STRING,
  owner STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_streaming_registry PRIMARY KEY (stream_id)
)
COMMENT 'Streams: checkpoints, schema tracking, SLO y replay.'
TBLPROPERTIES ('gov.activation' = 'STR', 'gov.reference' = 'N29', 'gov.writer' = 'Data Engineer');

-- ---------------------------------------------------------------- provenance
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.provenance COMMENT 'Procedencia física de documentos y evidencia por campo (patrón Cordillera).';

CREATE TABLE IF NOT EXISTS ${gov_catalog}.provenance.source_manifest (
  source_doc_id STRING NOT NULL,
  source_id STRING,
  publisher STRING,
  source_url STRING,
  file_uri STRING,
  sha256 STRING,
  mime_type STRING,
  revision STRING,
  language STRING,
  registered_at TIMESTAMP,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_source_manifest PRIMARY KEY (source_doc_id)
)
COMMENT 'Registro de documentos fuente con hash.'
TBLPROPERTIES ('gov.activation' = 'DOC', 'gov.reference' = 'GOV-LIN-003, N16', 'gov.writer' = 'Ingesta (service principal)');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.provenance.document_quarantine (
  doc_id STRING NOT NULL,
  sha256 STRING,
  reason STRING,
  detected_at TIMESTAMP,
  reviewer STRING,
  decision STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_document_quarantine PRIMARY KEY (doc_id)
)
COMMENT 'Documentos rechazados y su revisión.'
TBLPROPERTIES ('gov.activation' = 'DOC', 'gov.reference' = 'N16', 'gov.writer' = 'Ingesta (service principal)');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.provenance.processing_config (
  config_id STRING NOT NULL,
  version STRING NOT NULL,
  component STRING,
  parameters_json STRING,
  prompt_version STRING,
  model STRING,
  effective_from TIMESTAMP,
  git_commit STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_processing_config PRIMARY KEY (config_id, version)
)
COMMENT 'Configuración versionada de procesamiento (prompts, modelos, parámetros).'
TBLPROPERTIES ('gov.activation' = 'DOC;IA', 'gov.reference' = 'Patrón Cordillera', 'gov.writer' = 'AI/ML Engineer');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.provenance.field_evidence (
  evidence_id STRING NOT NULL,
  run_id STRING,
  uc_object STRING,
  record_key STRING,
  field STRING,
  value STRING,
  source_doc_id STRING,
  page INT,
  citation STRING,
  confidence DOUBLE,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_field_evidence PRIMARY KEY (evidence_id)
)
COMMENT 'Evidencia por campo: valor, documento, página y cita.'
TBLPROPERTIES ('gov.activation' = 'DOC', 'gov.reference' = 'GOV-LIN-003', 'gov.writer' = 'Pipeline (service principal)');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.provenance.parsing_errors (
  error_id STRING NOT NULL,
  run_id STRING,
  source_doc_id STRING,
  stage STRING,
  error_code STRING,
  message STRING,
  occurred_at TIMESTAMP,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_parsing_errors PRIMARY KEY (error_id)
)
COMMENT 'Errores de parseo e inferencia de documentos.'
TBLPROPERTIES ('gov.activation' = 'DOC', 'gov.reference' = 'Patrón Cordillera', 'gov.writer' = 'Pipeline (service principal)');

-- ---------------------------------------------------------------- processing
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.processing COMMENT 'Auditoría funcional de ejecuciones y activos desplegados.';

CREATE TABLE IF NOT EXISTS ${gov_catalog}.processing.processing_runs (
  run_id STRING NOT NULL,
  project_id STRING,
  job_or_pipeline_id STRING,
  started_at TIMESTAMP,
  ended_at TIMESTAMP,
  status STRING,
  records_in BIGINT,
  records_out BIGINT,
  config_id STRING,
  git_commit STRING,
  triggered_by STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_processing_runs PRIMARY KEY (run_id)
)
COMMENT 'Ejecuciones funcionales con métricas de negocio.'
TBLPROPERTIES ('gov.activation' = 'BASE@2', 'gov.reference' = 'GOV-AUD-004', 'gov.writer' = 'Jobs (service principal)');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.processing.processing_errors (
  error_id STRING NOT NULL,
  run_id STRING,
  stage STRING,
  error_code STRING,
  message STRING,
  record_key STRING,
  occurred_at TIMESTAMP,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_processing_errors PRIMARY KEY (error_id)
)
COMMENT 'Errores funcionales por ejecución.'
TBLPROPERTIES ('gov.activation' = 'BASE@2', 'gov.reference' = 'GOV-AUD-004', 'gov.writer' = 'Jobs (service principal)');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.processing.deployment_assets (
  asset_id STRING NOT NULL,
  project_id STRING,
  asset_type STRING,
  name STRING,
  workspace_id STRING,
  environment STRING,
  bundle_name STRING,
  git_commit STRING,
  deployed_at TIMESTAMP,
  deployed_by STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_deployment_assets PRIMARY KEY (asset_id)
)
COMMENT 'Inventario de activos desplegados por Bundles.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '28, Patrón Cordillera', 'gov.writer' = 'CI/CD (service principal)');

-- ---------------------------------------------------------------- review
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.review COMMENT 'Revisión humana (HITL), ground truth y validación.';

CREATE TABLE IF NOT EXISTS ${gov_catalog}.review.review_queue (
  review_id STRING NOT NULL,
  project_id STRING,
  uc_object STRING,
  record_key STRING,
  field STRING,
  proposed_value STRING,
  reason STRING,
  priority STRING,
  queued_at TIMESTAMP,
  sla_due_at TIMESTAMP,
  assigned_to STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_review_queue PRIMARY KEY (review_id)
)
COMMENT 'Casos pendientes de revisión humana.'
TBLPROPERTIES ('gov.activation' = 'HITL', 'gov.reference' = '23, GOV-AI-013', 'gov.writer' = 'Pipeline / App');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.review.review_decisions (
  decision_id STRING NOT NULL,
  review_id STRING,
  reviewer STRING,
  decision STRING,
  before_value STRING,
  after_value STRING,
  justification STRING,
  decided_at TIMESTAMP,
  writeback_status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_review_decisions PRIMARY KEY (decision_id)
)
COMMENT 'Decisiones humanas con antes/después y write-back.'
TBLPROPERTIES ('gov.activation' = 'HITL', 'gov.reference' = '23', 'gov.writer' = 'Revisor (App / ITSM)');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.review.reference_values (
  ref_id STRING NOT NULL,
  dataset STRING,
  record_key STRING,
  field STRING,
  expected_value STRING,
  source STRING,
  approved_by STRING,
  valid_from DATE,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_reference_values PRIMARY KEY (ref_id)
)
COMMENT 'Ground truth aprobado para evaluar resultados.'
TBLPROPERTIES ('gov.activation' = 'IA;HITL', 'gov.reference' = 'GOV-AI-008, N19', 'gov.writer' = 'Data Steward / SME');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.review.validation_results (
  validation_id STRING NOT NULL,
  run_id STRING,
  ref_id STRING,
  observed_value STRING,
  expected_value STRING,
  match BOOLEAN,
  metric STRING,
  evaluated_at TIMESTAMP,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_validation_results PRIMARY KEY (validation_id)
)
COMMENT 'Comparación esperado vs observado.'
TBLPROPERTIES ('gov.activation' = 'IA;HITL', 'gov.reference' = 'GOV-AI-008', 'gov.writer' = 'Job de evaluación');

-- ---------------------------------------------------------------- ai
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.ai COMMENT 'Gobierno de IA y agentes (solo atributos que MLflow y Unity Gateway no guardan).';

CREATE TABLE IF NOT EXISTS ${gov_catalog}.ai.ai_asset_registry (
  ai_asset_id STRING NOT NULL,
  project_id STRING,
  asset_type STRING,
  uc_object_or_endpoint STRING,
  owner STRING,
  purpose STRING,
  risk_tier STRING,
  dasf_risks STRING,
  human_review_required BOOLEAN,
  gateway_route STRING,
  mlflow_experiment STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_ai_asset_registry PRIMARY KEY (ai_asset_id)
)
COMMENT 'Inventario funcional de activos IA.'
TBLPROPERTIES ('gov.activation' = 'IA', 'gov.reference' = '21', 'gov.writer' = 'AI Gov Lead');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.ai.ai_risk_controls (
  ai_asset_id STRING NOT NULL,
  risk STRING NOT NULL,
  dasf_ref STRING,
  control_id STRING,
  metric STRING,
  threshold DOUBLE,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_ai_risk_controls PRIMARY KEY (ai_asset_id, risk)
)
COMMENT 'Riesgos IA (DASF) y su control.'
TBLPROPERTIES ('gov.activation' = 'IA', 'gov.reference' = '22, GOV-HRD-008', 'gov.writer' = 'AI Gov Lead');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.ai.ai_evaluation_index (
  eval_id STRING NOT NULL,
  ai_asset_id STRING,
  mlflow_run_id STRING,
  dataset_version STRING,
  pass_rate DOUBLE,
  red_team BOOLEAN,
  decision STRING,
  approved_by STRING,
  evaluated_at TIMESTAMP,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_ai_evaluation_index PRIMARY KEY (eval_id)
)
COMMENT 'Índice de evaluaciones y red team (enlaza a MLflow, no copia).'
TBLPROPERTIES ('gov.activation' = 'IA', 'gov.reference' = 'N19', 'gov.writer' = 'AI/ML Engineer');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.ai.agent_registry (
  agent_id STRING NOT NULL,
  agent_type STRING,
  allowed_models STRING,
  allowed_mcp STRING,
  allowed_skills STRING,
  auto_approve BOOLEAN,
  web_search BOOLEAN,
  memory_enabled BOOLEAN,
  channels STRING,
  owner STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_agent_registry PRIMARY KEY (agent_id)
)
COMMENT 'Agentes y coding agents permitidos y su configuración.'
TBLPROPERTIES ('gov.activation' = 'IA;BASE@3', 'gov.reference' = 'N34, GOV-AI-020/021', 'gov.writer' = 'AI Gov Lead');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.ai.ai_incidents (
  incident_id STRING NOT NULL,
  ai_asset_id STRING,
  incident_type STRING,
  severity STRING,
  detected_at TIMESTAMP,
  description STRING,
  action STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_ai_incidents PRIMARY KEY (incident_id)
)
COMMENT 'Incidentes de IA.'
TBLPROPERTIES ('gov.activation' = 'IA', 'gov.reference' = 'N13', 'gov.writer' = 'AI Gov Lead');

-- ---------------------------------------------------------------- privacy
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.privacy COMMENT 'Privacidad, retención y purga.';

CREATE TABLE IF NOT EXISTS ${gov_catalog}.privacy.retention_policies (
  policy_id STRING NOT NULL,
  data_class STRING,
  retention_days INT,
  archive_after_days INT,
  delete_after_days INT,
  legal_basis STRING,
  ttl_mechanism STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_retention_policies PRIMARY KEY (policy_id)
)
COMMENT 'Retención por clase de dato y mecanismo (Auto-TTL o job).'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '20, GOV-RET-001/004', 'gov.writer' = 'Data Steward');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.privacy.purge_log (
  purge_id STRING NOT NULL,
  uc_object STRING,
  policy_id STRING,
  executed_at TIMESTAMP,
  rows_deleted BIGINT,
  vacuum_executed BOOLEAN,
  evidence_uri STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_purge_log PRIMARY KEY (purge_id)
)
COMMENT 'Evidencia de purgas y VACUUM.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'GOV-RET-002', 'gov.writer' = 'Job de purga');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.privacy.legal_holds (
  hold_id STRING NOT NULL,
  uc_object STRING,
  reason STRING,
  requested_by STRING,
  start_date DATE,
  end_date DATE,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_legal_holds PRIMARY KEY (hold_id)
)
COMMENT 'Retenciones legales que suspenden la purga.'
TBLPROPERTIES ('gov.activation' = 'BASE@3;REG', 'gov.reference' = 'GOV-RET-003', 'gov.writer' = 'Risk/Compliance');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.privacy.dpia_register (
  dpia_id STRING NOT NULL,
  project_id STRING,
  purpose STRING,
  legal_basis STRING,
  risks STRING,
  measures STRING,
  approved_by STRING,
  approved_at DATE,
  review_date DATE,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_dpia_register PRIMARY KEY (dpia_id)
)
COMMENT 'Evaluaciones de impacto de privacidad.'
TBLPROPERTIES ('gov.activation' = 'PII', 'gov.reference' = 'N04, GOV-PRV-001', 'gov.writer' = 'Risk/Compliance');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.privacy.dsar_requests (
  request_id STRING NOT NULL,
  subject_ref_hash STRING,
  request_type STRING,
  received_at TIMESTAMP,
  due_at TIMESTAMP,
  status STRING,
  handler STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_dsar_requests PRIMARY KEY (request_id)
)
COMMENT 'Solicitudes de derechos del titular (identificador con hash).'
TBLPROPERTIES ('gov.activation' = 'PII', 'gov.reference' = 'N04', 'gov.writer' = 'Risk/Compliance');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.privacy.dsar_execution_log (
  request_id STRING NOT NULL,
  uc_object STRING NOT NULL,
  action STRING NOT NULL,
  executed_at TIMESTAMP,
  rows_affected BIGINT,
  verified BOOLEAN,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_dsar_execution_log PRIMARY KEY (request_id, uc_object, action)
)
COMMENT 'Ejecución de la supresión en tabla, SCD2, CDF y time travel.'
TBLPROPERTIES ('gov.activation' = 'PII', 'gov.reference' = 'N04, GOV-PRV-002', 'gov.writer' = 'Job DSAR');

-- ---------------------------------------------------------------- access
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.access COMMENT 'Procesos de acceso (los permisos viven en Unity Catalog, nunca aquí).';

CREATE TABLE IF NOT EXISTS ${gov_catalog}.access.access_reviews (
  review_id STRING NOT NULL,
  cycle STRING,
  principal STRING,
  securable STRING,
  privilege STRING,
  reviewer STRING,
  decision STRING,
  decided_at TIMESTAMP,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_access_reviews PRIMARY KEY (review_id)
)
COMMENT 'Recertificación periódica de accesos.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'N14, GOV-ACC-007', 'gov.writer' = 'Data Owner');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.access.temporary_access (
  grant_ref STRING NOT NULL,
  principal_group STRING,
  securable STRING,
  privilege STRING,
  approved_by STRING,
  start_at TIMESTAMP,
  expires_at TIMESTAMP,
  revoked_at TIMESTAMP,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_temporary_access PRIMARY KEY (grant_ref)
)
COMMENT 'Accesos temporales con vencimiento.'
TBLPROPERTIES ('gov.activation' = 'BASE@2', 'gov.reference' = 'GOV-ACC-006', 'gov.writer' = 'Security');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.access.sod_rules (
  rule_id STRING NOT NULL,
  role_a STRING,
  role_b STRING,
  description STRING,
  severity STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_sod_rules PRIMARY KEY (rule_id)
)
COMMENT 'Reglas de segregación de funciones.'
TBLPROPERTIES ('gov.activation' = 'BASE@2', 'gov.reference' = 'GOV-ACC-005', 'gov.writer' = 'Security');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.access.access_requests_log (
  request_id STRING NOT NULL,
  requester STRING,
  securable STRING,
  privilege STRING,
  justification STRING,
  decision STRING,
  approver STRING,
  ticket_id STRING,
  requested_at TIMESTAMP,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_access_requests_log PRIMARY KEY (request_id)
)
COMMENT 'Solicitudes de acceso (solo si no se usa UC Access Requests ni ITSM).'
TBLPROPERTIES ('gov.activation' = 'OPT', 'gov.reference' = '13', 'gov.writer' = 'Security');

-- ---------------------------------------------------------------- sharing
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.sharing COMMENT 'Compartición con terceros y licencias.';

CREATE TABLE IF NOT EXISTS ${gov_catalog}.sharing.sharing_agreements (
  agreement_id STRING NOT NULL,
  share_name STRING,
  recipient STRING,
  purpose STRING,
  datasets STRING,
  classification STRING,
  legal_basis STRING,
  expiration DATE,
  approved_by STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_sharing_agreements PRIMARY KEY (agreement_id)
)
COMMENT 'Acuerdos de compartición (OpenSharing / Clean Rooms).'
TBLPROPERTIES ('gov.activation' = 'SHARE', 'gov.reference' = 'N12, GOV-SHR-001', 'gov.writer' = 'Data Owner');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.sharing.recipient_reviews (
  review_id STRING NOT NULL,
  recipient STRING,
  reviewed_at TIMESTAMP,
  reviewer STRING,
  decision STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_recipient_reviews PRIMARY KEY (review_id)
)
COMMENT 'Revisión periódica de recipients.'
TBLPROPERTIES ('gov.activation' = 'SHARE', 'gov.reference' = 'GOV-SHR-002', 'gov.writer' = 'Data Owner');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.sharing.data_licenses (
  license_id STRING NOT NULL,
  provider STRING,
  dataset STRING,
  uc_objects STRING,
  allowed_use STRING,
  redistribution_allowed BOOLEAN,
  expiration DATE,
  owner STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_data_licenses PRIMARY KEY (license_id)
)
COMMENT 'Licencias de datos de terceros.'
TBLPROPERTIES ('gov.activation' = 'LIC', 'gov.reference' = 'N33', 'gov.writer' = 'Data Owner');

-- ---------------------------------------------------------------- semantic
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.semantic COMMENT 'Capa semántica y Genie (las definiciones viven en el YAML de las Metric Views y en Genie).';

CREATE TABLE IF NOT EXISTS ${gov_catalog}.semantic.metric_registry (
  metric_id STRING NOT NULL,
  metric_view STRING,
  measure_name STRING,
  domain_id STRING,
  owner STRING,
  steward STRING,
  definition STRING,
  formula_approved_by STRING,
  version STRING,
  certification_status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_metric_registry PRIMARY KEY (metric_id)
)
COMMENT 'Registro funcional de métricas oficiales.'
TBLPROPERTIES ('gov.activation' = 'SEM', 'gov.reference' = '32', 'gov.writer' = 'Metric Owner');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.semantic.metric_equivalence_tests (
  test_id STRING NOT NULL,
  metric_id STRING,
  gold_sql_uri STRING,
  mv_sql_uri STRING,
  tolerance DOUBLE,
  last_result STRING,
  last_run TIMESTAMP,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_metric_equivalence_tests PRIMARY KEY (test_id)
)
COMMENT 'Pruebas Metric View vs SQL Gold.'
TBLPROPERTIES ('gov.activation' = 'SEM', 'gov.reference' = '39, GOV-SEM-002', 'gov.writer' = 'QA');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.semantic.semantic_conflicts (
  conflict_id STRING NOT NULL,
  term_or_metric STRING,
  definitions STRING,
  domains STRING,
  owner STRING,
  resolution STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_semantic_conflicts PRIMARY KEY (conflict_id)
)
COMMENT 'Conflictos entre definiciones y su resolución.'
TBLPROPERTIES ('gov.activation' = 'SEM', 'gov.reference' = 'GOV-SEM-001, GOV-ONT-004', 'gov.writer' = 'Gov Lead');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.semantic.genie_agent_registry (
  agent_id STRING NOT NULL,
  domain_id STRING,
  owner STRING,
  warehouse_id STRING,
  sources STRING,
  instructions_version STRING,
  knowledge_store_version STRING,
  environment STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_genie_agent_registry PRIMARY KEY (agent_id)
)
COMMENT 'Genie Agents: fuentes, versiones y ambiente.'
TBLPROPERTIES ('gov.activation' = 'GENIE', 'gov.reference' = '35', 'gov.writer' = 'Agent Curator');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.semantic.genie_benchmarks (
  benchmark_id STRING NOT NULL,
  agent_id STRING,
  question STRING,
  language STRING,
  category STRING,
  expected_sql STRING,
  expected_behavior STRING,
  criticality STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_genie_benchmarks PRIMARY KEY (benchmark_id)
)
COMMENT 'Benchmarks versionados como código (complementa los benchmarks nativos).'
TBLPROPERTIES ('gov.activation' = 'GENIE;ONT', 'gov.reference' = '37, N24', 'gov.writer' = 'QA');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.semantic.genie_benchmark_results (
  run_id STRING NOT NULL,
  benchmark_id STRING NOT NULL,
  executed_at TIMESTAMP,
  result STRING,
  notes STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_genie_benchmark_results PRIMARY KEY (run_id, benchmark_id)
)
COMMENT 'Resultados de benchmarks por ejecución.'
TBLPROPERTIES ('gov.activation' = 'GENIE;ONT', 'gov.reference' = '37, N24', 'gov.writer' = 'CI/CD');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.semantic.ontology_readiness (
  domain_id STRING NOT NULL,
  assessed_at DATE NOT NULL,
  critical_metrics_certified_pct DOUBLE,
  critical_terms_with_page_pct DOUBLE,
  conflicts_open INT,
  benchmark_pass_pct DOUBLE,
  readiness_status STRING,
  owner STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_ontology_readiness PRIMARY KEY (domain_id, assessed_at)
)
COMMENT 'Readiness de la Ontology por dominio.'
TBLPROPERTIES ('gov.activation' = 'ONT', 'gov.reference' = '38', 'gov.writer' = 'Gov Architect');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.semantic.ontology_hygiene_log (
  action_id STRING NOT NULL,
  asset STRING,
  action STRING,
  reason STRING,
  executed_at TIMESTAMP,
  executed_by STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_ontology_hygiene_log PRIMARY KEY (action_id)
)
COMMENT 'Higiene de fuentes del contexto inferido.'
TBLPROPERTIES ('gov.activation' = 'ONT', 'gov.reference' = 'N23, GOV-ONT-002', 'gov.writer' = 'Data Steward');

-- ---------------------------------------------------------------- platform
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.platform COMMENT 'Plataforma, operación y FinOps.';

CREATE TABLE IF NOT EXISTS ${gov_catalog}.platform.slo_definitions (
  slo_id STRING NOT NULL,
  asset STRING,
  metric STRING,
  target DOUBLE,
  slo_window STRING,
  warning DOUBLE,
  critical DOUBLE,
  alert_id STRING,
  runbook_uri STRING,
  owner STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_slo_definitions PRIMARY KEY (slo_id)
)
COMMENT 'SLO por activo con alerta y runbook.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = '24, GOV-OPS-001', 'gov.writer' = 'DataOps');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.platform.incidents (
  incident_id STRING NOT NULL,
  incident_type STRING,
  severity STRING,
  detected_at TIMESTAMP,
  description STRING,
  rca STRING,
  actions STRING,
  status STRING,
  closed_at TIMESTAMP,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_incidents PRIMARY KEY (incident_id)
)
COMMENT 'Incidentes de datos, calidad, seguridad, IA y semántica.'
TBLPROPERTIES ('gov.activation' = 'BASE@2', 'gov.reference' = 'N13', 'gov.writer' = 'DataOps');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.platform.platform_settings_baseline (
  setting_key STRING NOT NULL,
  scope STRING NOT NULL,
  expected_value STRING,
  justification STRING,
  actual_value STRING,
  compliant BOOLEAN,
  last_checked TIMESTAMP,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_platform_settings_baseline PRIMARY KEY (setting_key, scope)
)
COMMENT 'Settings esperados vs reales del workspace y la cuenta.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'N25, GOV-HRD-002', 'gov.writer' = 'Platform Admin');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.platform.preview_decisions (
  preview_name STRING NOT NULL,
  workspace_id STRING NOT NULL,
  enabled BOOLEAN,
  adr_id STRING,
  approved_by STRING,
  review_date DATE,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_preview_decisions PRIMARY KEY (preview_name, workspace_id)
)
COMMENT 'Previews habilitadas y su ADR.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'GOV-HRD-007', 'gov.writer' = 'Platform Admin');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.platform.release_watch (
  item_id STRING NOT NULL,
  review_month STRING,
  feature STRING,
  change_type STRING,
  maturity STRING,
  impact STRING,
  decision STRING,
  adr_id STRING,
  reviewed_at DATE,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_release_watch PRIMARY KEY (item_id)
)
COMMENT 'Revisión trimestral de release notes.'
TBLPROPERTIES ('gov.activation' = 'BASE@2', 'gov.reference' = 'N27', 'gov.writer' = 'Platform Admin');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.platform.cost_center_map (
  cost_center STRING NOT NULL,
  project_id STRING,
  domain_id STRING,
  owner STRING,
  budget_id STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_cost_center_map PRIMARY KEY (cost_center)
)
COMMENT 'Cost centers por proyecto y dominio.'
TBLPROPERTIES ('gov.activation' = 'BASE', 'gov.reference' = 'N08, GOV-FIN-001', 'gov.writer' = 'Platform Admin');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.platform.hms_migration_tracker (
  object_name STRING NOT NULL,
  hms_location STRING,
  uc_target STRING,
  wave STRING,
  status STRING,
  migrated_at TIMESTAMP,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_hms_migration_tracker PRIMARY KEY (object_name)
)
COMMENT 'Seguimiento de la migración Hive Metastore → UC.'
TBLPROPERTIES ('gov.activation' = 'HMS', 'gov.reference' = 'N26', 'gov.writer' = 'Platform Admin');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.platform.region_topology (
  metastore_id STRING NOT NULL,
  region STRING,
  cloud STRING,
  workspaces STRING,
  data_classes_allowed STRING,
  residency_rules STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_region_topology PRIMARY KEY (metastore_id)
)
COMMENT 'Metastores, regiones y residencia permitida.'
TBLPROPERTIES ('gov.activation' = 'MULTI', 'gov.reference' = 'N31', 'gov.writer' = 'Platform Admin');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.platform.cross_region_flows (
  flow_id STRING NOT NULL,
  source_region STRING,
  target_region STRING,
  mechanism STRING,
  datasets STRING,
  approved_by STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_cross_region_flows PRIMARY KEY (flow_id)
)
COMMENT 'Flujos de datos entre regiones aprobados.'
TBLPROPERTIES ('gov.activation' = 'MULTI', 'gov.reference' = 'N31, GOV-MULTI-002', 'gov.writer' = 'Risk/Compliance');

-- ---------------------------------------------------------------- consumption
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.consumption COMMENT 'Consumo gobernado fuera de notebooks: BI externo, apps y contratos entre dominios.';

CREATE TABLE IF NOT EXISTS ${gov_catalog}.consumption.bi_reports_registry (
  report_id STRING NOT NULL,
  tool STRING,
  name STRING,
  owner STRING,
  sources STRING,
  connection_mode STRING,
  contains_sensitive BOOLEAN,
  certification STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_bi_reports_registry PRIMARY KEY (report_id)
)
COMMENT 'Reportes BI externos: owner, fuentes y modo de conexión.'
TBLPROPERTIES ('gov.activation' = 'BI', 'gov.reference' = 'N28, GOV-BI-003/004', 'gov.writer' = 'Analytics Owner');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.consumption.app_registry (
  app_id STRING NOT NULL,
  name STRING,
  owner STRING,
  service_principal STRING,
  auth_mode STRING,
  data_accessed STRING,
  lakebase_db STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_app_registry PRIMARY KEY (app_id)
)
COMMENT 'Databricks Apps: SP, autorización y datos expuestos.'
TBLPROPERTIES ('gov.activation' = 'APP', 'gov.reference' = 'N32', 'gov.writer' = 'Security');

CREATE TABLE IF NOT EXISTS ${gov_catalog}.consumption.domain_interface_contracts (
  interface_id STRING NOT NULL,
  producer_domain STRING,
  consumer_domain STRING,
  product_id STRING,
  contract_id STRING,
  status STRING,
  created_at TIMESTAMP,
  created_by STRING,
  updated_at TIMESTAMP,
  updated_by STRING,
  CONSTRAINT pk_domain_interface_contracts PRIMARY KEY (interface_id)
)
COMMENT 'Contratos de interfaz entre dominios (data mesh).'
TBLPROPERTIES ('gov.activation' = 'MESH', 'gov.reference' = 'N30', 'gov.writer' = 'Gov Lead');

-- ---------------------------------------------------------------- evidence (vistas)
CREATE SCHEMA IF NOT EXISTS ${gov_catalog}.evidence COMMENT 'Vistas de evidencia sobre system tables y tablas de gobierno (no copian datos)';
-- Validar nombres de columnas de system tables en tu región/versión antes de ejecutar.

CREATE OR REPLACE VIEW ${gov_catalog}.evidence.v_grants_to_users
COMMENT 'Grants otorgados directamente a usuarios (deben ser 0). (GOV-ACC-001)'
AS
SELECT grantor, grantee, table_catalog, table_schema, table_name, privilege_type
FROM system.information_schema.table_privileges
WHERE grantee LIKE '%@%';

CREATE OR REPLACE VIEW ${gov_catalog}.evidence.v_all_privileges_grants
COMMENT 'Grants ALL PRIVILEGES (revisar en PROD). (GOV-ACC-002)'
AS
SELECT grantee, table_catalog, table_schema, table_name
FROM system.information_schema.table_privileges
WHERE privilege_type = 'ALL PRIVILEGES';

CREATE OR REPLACE VIEW ${gov_catalog}.evidence.v_columns_without_comment
COMMENT 'Columnas sin descripción. (GOV-MET-001)'
AS
SELECT table_catalog, table_schema, table_name, column_name
FROM system.information_schema.columns
WHERE (comment IS NULL OR comment = '') AND table_schema <> 'information_schema';

CREATE OR REPLACE VIEW ${gov_catalog}.evidence.v_access_events_30d
COMMENT 'Eventos de auditoría de los últimos 30 días. (GOV-AUD-001)'
AS
SELECT event_time, user_identity.email AS user_email, service_name, action_name
FROM system.access.audit
WHERE event_date >= date_sub(current_date(), 30);

CREATE OR REPLACE VIEW ${gov_catalog}.evidence.v_cost_by_cost_center
COMMENT 'Consumo por cost_center (tag de costo). (GOV-FIN-001)'
AS
SELECT usage_date, custom_tags['cost_center'] AS cost_center, sku_name, SUM(usage_quantity) AS usage_quantity
FROM system.billing.usage
GROUP BY ALL;

CREATE OR REPLACE VIEW ${gov_catalog}.evidence.v_control_status
COMMENT 'Último resultado de las pruebas de cada control. (17, 25)'
AS
SELECT c.control_id, c.domain, c.description, r.result, r.executed_at
FROM ${gov_catalog}.risk_control.controls c
LEFT JOIN (SELECT t.control_id, x.result, x.executed_at,
                  ROW_NUMBER() OVER (PARTITION BY t.control_id ORDER BY x.executed_at DESC) AS rn
           FROM ${gov_catalog}.risk_control.control_tests t JOIN ${gov_catalog}.risk_control.control_test_results x ON x.test_id = t.test_id) r
  ON r.control_id = c.control_id AND r.rn = 1;

CREATE OR REPLACE VIEW ${gov_catalog}.evidence.v_exceptions_expired
COMMENT 'Excepciones vencidas y abiertas. (GOV-EXC-001)'
AS
SELECT * FROM ${gov_catalog}.risk_control.exceptions WHERE expiration_date < current_date() AND status <> 'CERRADA';

CREATE OR REPLACE VIEW ${gov_catalog}.evidence.v_deliverables_progress
COMMENT 'Avance de entregables por proyecto. (R1)'
AS
SELECT project_id, COUNT(*) AS total, SUM(CASE WHEN status IN ('Completo','Ya existe') THEN 1 ELSE 0 END) AS completos
FROM ${gov_catalog}.risk_control.deliverables_status GROUP BY project_id;
