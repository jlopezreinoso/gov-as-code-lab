"""Job gov_ai_eval (condicional IA / HITL): mide exactitud contra ground truth, nunca contra la confianza del modelo.

Compara una tabla de predicciones (record_key, field, value) con review.reference_values del dataset indicado,
escribe review.validation_results y registra el resumen en ai.ai_evaluation_index (si MLflow está disponible,
también crea un run con la métrica y guarda su id). GOV-AI-008: sin pasar el umbral, no hay promoción.
"""
from __future__ import annotations

from gov_specs import base_parser, id_of


def normalize(v) -> str:
    return "" if v is None else " ".join(str(v).split()).lower()


def main() -> None:
    p = base_parser("Evaluación de IA contra ground truth")
    p.add_argument("--ai-asset-id", required=True)
    p.add_argument("--predictions-table", required=True, help="Tabla con columnas record_key, field, value")
    p.add_argument("--dataset", required=True, help="dataset en review.reference_values")
    p.add_argument("--dataset-version", default="1")
    p.add_argument("--threshold", type=float, default=0.95)
    p.add_argument("--run-id", default=None)
    a = p.parse_args()
    from pyspark.sql import SparkSession
    from gov_lib import Gov
    spark = SparkSession.builder.getOrCreate()
    gov, c = Gov(spark, a.gov_catalog), a.gov_catalog
    run_id = a.run_id or id_of(a.ai_asset_id, a.dataset, gov._now())

    pairs = spark.sql(f"""
        SELECT r.ref_id, r.expected_value, p.value AS observed_value
        FROM {c}.review.reference_values r
        LEFT JOIN {a.predictions_table} p ON p.record_key = r.record_key AND p.field = r.field
        WHERE r.dataset = '{a.dataset}'""").collect()
    rows = [{"validation_id": id_of(run_id, x.ref_id), "run_id": run_id, "ref_id": x.ref_id,
             "observed_value": x.observed_value, "expected_value": x.expected_value,
             "match": normalize(x.observed_value) == normalize(x.expected_value), "metric": "exact_match",
             "evaluated_at": gov._now()} for x in pairs]
    gov.merge("review.validation_results", ["validation_id"], rows)
    rate = sum(r["match"] for r in rows) / len(rows) if rows else 0.0

    mlflow_run = None
    try:
        import mlflow
        with mlflow.start_run(run_name=f"gov_eval_{a.ai_asset_id}") as r:
            mlflow.log_metric("exact_match", rate)
            mlflow.log_params({"dataset": a.dataset, "dataset_version": a.dataset_version})
            mlflow_run = r.info.run_id
    except Exception as ex:  # MLflow es opcional en este job; la evidencia queda igual en las tablas
        print(f"MLflow no disponible: {ex}")
    decision = "APROBADO" if rate >= a.threshold else "RECHAZADO"
    gov.merge("ai.ai_evaluation_index", ["eval_id"], [{
        "eval_id": run_id, "ai_asset_id": a.ai_asset_id, "mlflow_run_id": mlflow_run, "dataset_version": a.dataset_version,
        "pass_rate": rate, "red_team": False, "decision": decision, "evaluated_at": gov._now()}])
    print(f"{a.ai_asset_id}: exact_match={rate:.3f} sobre {len(rows)} casos → {decision}")
    if decision == "RECHAZADO":
        raise SystemExit("Evaluación bajo el umbral: no promover")


if __name__ == "__main__":
    main()
