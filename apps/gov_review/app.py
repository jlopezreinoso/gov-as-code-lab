"""App de gobierno (Databricks App): registra las decisiones humanas en el catálogo de gobierno.

Pestañas: revisión HITL · excepciones · recertificación de accesos · firmas de gate · incidentes.
Escribe con el service principal de la App (grupo 'app' en gov_grants) mediante un SQL warehouse y
consultas parametrizadas; registra al usuario real (cabecera X-Forwarded-Email que entrega Databricks Apps).
"""
from __future__ import annotations

import os
import uuid

import pandas as pd
import streamlit as st
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.sql import StatementParameterListItem

CAT = os.environ["GOV_CATALOG"]
WAREHOUSE = os.environ["DATABRICKS_WAREHOUSE_ID"]
w = WorkspaceClient()


def user() -> str:
    return st.context.headers.get("X-Forwarded-Email") or st.context.headers.get("X-Forwarded-Preferred-Username") or "desconocido"


def sql(statement: str, **params) -> pd.DataFrame:
    r = w.statement_execution.execute_statement(
        statement=statement, warehouse_id=WAREHOUSE, wait_timeout="30s",
        parameters=[StatementParameterListItem(name=k, value=None if v is None else str(v)) for k, v in params.items()])
    if r.status and r.status.error:
        raise RuntimeError(r.status.error.message)
    if not r.manifest or not r.manifest.schema or not r.manifest.schema.columns:
        return pd.DataFrame()
    cols = [c.name for c in r.manifest.schema.columns]
    return pd.DataFrame((r.result.data_array if r.result else None) or [], columns=cols)


AUDIT_INS = "current_timestamp(), :usr, current_timestamp(), :usr"

st.set_page_config(page_title="Gobierno de datos — decisiones", layout="wide")
st.title("Gobierno de datos — decisiones humanas")
st.caption(f"Catálogo {CAT} · usuario {user()}")
tabs = st.tabs(["Revisión HITL", "Excepciones", "Recertificación de accesos", "Firmas de gate", "Incidentes"])

with tabs[0]:
    q = sql(f"SELECT review_id, uc_object, record_key, field, proposed_value, reason, priority, sla_due_at "
            f"FROM {CAT}.review.review_queue WHERE status = 'PENDIENTE' ORDER BY sla_due_at")
    st.dataframe(q, use_container_width=True)
    if not q.empty:
        with st.form("hitl"):
            rid = st.selectbox("Caso", q["review_id"])
            dec = st.radio("Decisión", ["APROBADO", "RECHAZADO", "CORREGIDO", "ESCALADO"], horizontal=True)
            after = st.text_input("Valor final (si corrige)")
            why = st.text_area("Justificación (obligatoria)")
            if st.form_submit_button("Registrar decisión"):
                if not why.strip():
                    st.error("La justificación es obligatoria (WHO/WHEN/WHAT/WHY).")
                else:
                    before = q.loc[q["review_id"] == rid, "proposed_value"].iloc[0]
                    sql(f"INSERT INTO {CAT}.review.review_decisions (decision_id, review_id, reviewer, decision, before_value, "
                        f"after_value, justification, decided_at, writeback_status, created_at, created_by, updated_at, updated_by) "
                        f"VALUES (:id, :rid, :usr, :dec, :before, :after, :why, current_timestamp(), 'PENDIENTE', {AUDIT_INS})",
                        id=uuid.uuid4().hex, rid=rid, usr=user(), dec=dec, before=before, after=after or before, why=why)
                    sql(f"UPDATE {CAT}.review.review_queue SET status = :dec, updated_at = current_timestamp(), updated_by = :usr "
                        f"WHERE review_id = :rid", dec=dec, usr=user(), rid=rid)
                    st.success("Decisión registrada. El write-back lo aplica el pipeline del dominio.")
                    st.rerun()

with tabs[1]:
    st.subheader("Solicitar excepción")
    with st.form("exc_new"):
        ctl, asset = st.text_input("Control (p. ej. GOV-ACC-001)"), st.text_input("Activo")
        reason, comp = st.text_area("Motivo"), st.text_area("Control compensatorio")
        exp = st.date_input("Vence el (obligatorio)")
        risk = st.selectbox("Riesgo residual", ["BAJO", "MEDIO", "ALTO"])
        if st.form_submit_button("Solicitar"):
            sql(f"INSERT INTO {CAT}.risk_control.exceptions (exception_id, control_id, asset, reason, requested_by, compensating_control, "
                f"start_date, expiration_date, residual_risk, status, created_at, created_by, updated_at, updated_by) "
                f"VALUES (:id, :ctl, :asset, :reason, :usr, :comp, current_date(), CAST(:exp AS DATE), :risk, 'SOLICITADA', {AUDIT_INS})",
                id="EXC-" + uuid.uuid4().hex[:8].upper(), ctl=ctl, asset=asset, reason=reason, usr=user(), comp=comp, exp=exp, risk=risk)
            st.success("Excepción solicitada.")
    st.subheader("Aprobar excepciones")
    pend = sql(f"SELECT exception_id, control_id, asset, reason, requested_by, expiration_date, residual_risk "
               f"FROM {CAT}.risk_control.exceptions WHERE status = 'SOLICITADA'")
    st.dataframe(pend, use_container_width=True)
    if not pend.empty:
        with st.form("exc_ok"):
            eid = st.selectbox("Excepción", pend["exception_id"])
            ok = st.radio("Decisión", ["APROBADA", "RECHAZADA"], horizontal=True)
            if st.form_submit_button("Registrar"):
                if pend.loc[pend["exception_id"] == eid, "requested_by"].iloc[0] == user():
                    st.error("Segregación de funciones: quien solicita no puede aprobar.")
                else:
                    sql(f"UPDATE {CAT}.risk_control.exceptions SET status = :ok, approved_by = :usr, updated_at = current_timestamp(), "
                        f"updated_by = :usr WHERE exception_id = :eid", ok=ok, usr=user(), eid=eid)
                    st.success("Registrado.")
                    st.rerun()

with tabs[2]:
    r = sql(f"SELECT review_id, cycle, principal, securable, privilege FROM {CAT}.access.access_reviews WHERE decision = 'PENDIENTE'")
    st.dataframe(r, use_container_width=True)
    if not r.empty:
        with st.form("acc"):
            ids = st.multiselect("Revisiones", r["review_id"])
            dec = st.radio("Decisión", ["MANTENER", "REVOCAR"], horizontal=True)
            if st.form_submit_button("Registrar") and ids:
                for i in ids:
                    sql(f"UPDATE {CAT}.access.access_reviews SET decision = :dec, reviewer = :usr, decided_at = current_timestamp(), "
                        f"updated_at = current_timestamp(), updated_by = :usr WHERE review_id = :id", dec=dec, usr=user(), id=i)
                st.success(f"{len(ids)} revisiones registradas. Las revocaciones las ejecuta el equipo de seguridad vía PR de grants.")
                st.rerun()

with tabs[3]:
    with st.form("gate"):
        prj = st.text_input("Proyecto (project_id)")
        gate = st.selectbox("Gate", ["Pre-G0", "G0", "G1", "G2", "G3", "G4", "G5", "G6", "G7"])
        role = st.selectbox("Rol que firma", ["Data Owner", "Data Steward", "Security", "Risk/Compliance", "Gov Lead", "QA"])
        dec = st.radio("Decisión", ["APROBADO", "RECHAZADO", "APROBADO CON OBSERVACIONES"], horizontal=True)
        com = st.text_area("Comentarios")
        if st.form_submit_button("Firmar"):
            sql(f"MERGE INTO {CAT}.risk_control.gate_signoffs t USING (SELECT :prj AS project_id, :gate AS gate, :role AS role) s "
                f"ON t.project_id = s.project_id AND t.gate = s.gate AND t.role = s.role "
                f"WHEN MATCHED THEN UPDATE SET approver = :usr, decision = :dec, signed_at = current_timestamp(), comments = :com, "
                f"updated_at = current_timestamp(), updated_by = :usr "
                f"WHEN NOT MATCHED THEN INSERT (project_id, gate, role, approver, decision, signed_at, comments, created_at, created_by, updated_at, updated_by) "
                f"VALUES (:prj, :gate, :role, :usr, :dec, current_timestamp(), :com, {AUDIT_INS})",
                prj=prj, gate=gate, role=role, usr=user(), dec=dec, com=com)
            st.success("Firma registrada.")

with tabs[4]:
    with st.form("inc"):
        typ = st.selectbox("Tipo", ["DATOS", "CALIDAD", "SEGURIDAD", "IA", "SEMANTICO", "PRIVACIDAD"])
        sev = st.selectbox("Severidad", ["BAJA", "MEDIA", "ALTA", "CRITICA"])
        desc = st.text_area("Descripción")
        if st.form_submit_button("Registrar incidente"):
            sql(f"INSERT INTO {CAT}.platform.incidents (incident_id, incident_type, severity, detected_at, description, status, "
                f"created_at, created_by, updated_at, updated_by) VALUES (:id, :typ, :sev, current_timestamp(), :desc, 'ABIERTO', {AUDIT_INS})",
                id="INC-" + uuid.uuid4().hex[:8].upper(), typ=typ, sev=sev, desc=desc, usr=user())
            st.success("Incidente registrado.")
    st.dataframe(sql(f"SELECT incident_id, incident_type, severity, status, detected_at FROM {CAT}.platform.incidents "
                     f"ORDER BY detected_at DESC LIMIT 50"), use_container_width=True)
