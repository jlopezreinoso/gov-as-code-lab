"""Job gov_genie_benchmarks (condicional GENIE / ONT): ejecuta semantic.genie_benchmarks y registra resultados.

Para cada pregunta: la envía al Genie Agent (Conversation API del SDK), toma el SQL generado y compara su resultado
con el de expected_sql. Mismo conjunto de filas = PASS. Sin expected_sql, el benchmark solo verifica que haya
respuesta y queda como REVISAR. Validar el nombre de los métodos del SDK (w.genie.*) en tu versión.
"""
from __future__ import annotations

from gov_specs import base_parser, id_of


def same_result(expected: list[tuple], actual: list[tuple]) -> bool:
    norm = lambda rows: sorted(tuple("" if v is None else str(v) for v in r) for r in rows)
    return norm(expected) == norm(actual)


def main() -> None:
    p = base_parser("Benchmarks de Genie Agents")
    p.add_argument("--agent-id", default=None, help="Solo este agente (id del Genie Agent / space)")
    p.add_argument("--min-pass-rate", type=float, default=0.9)
    a = p.parse_args()
    from databricks.sdk import WorkspaceClient
    from pyspark.sql import SparkSession
    from gov_lib import Gov
    spark = SparkSession.builder.getOrCreate()
    gov, c, w = Gov(spark, a.gov_catalog), a.gov_catalog, WorkspaceClient()
    where = f"WHERE agent_id = '{a.agent_id}'" if a.agent_id else ""
    benches = spark.sql(f"SELECT benchmark_id, agent_id, question, expected_sql FROM {c}.semantic.genie_benchmarks {where}").collect()
    run_id, rows = id_of("genie", gov._now()), []
    for b in benches:
        result, notes = "ERROR", ""
        try:
            msg = w.genie.start_conversation_and_wait(space_id=b.agent_id, content=b.question)
            sql = next((att.query.query for att in (msg.attachments or []) if getattr(att, "query", None)), None)
            if not sql:
                result, notes = "FAIL", "Genie no generó SQL"
            elif not b.expected_sql:
                result, notes = "REVISAR", f"SQL generado: {sql[:1500]}"
            else:
                ok = same_result([tuple(r) for r in spark.sql(b.expected_sql).collect()], [tuple(r) for r in spark.sql(sql).collect()])
                result, notes = ("PASS" if ok else "FAIL"), sql[:1500]
        except Exception as ex:
            notes = str(ex)[:1500]
        rows.append({"run_id": run_id, "benchmark_id": b.benchmark_id, "executed_at": gov._now(), "result": result, "notes": notes})
    gov.merge("semantic.genie_benchmark_results", ["run_id", "benchmark_id"], rows)
    rate = sum(r["result"] == "PASS" for r in rows) / len(rows) if rows else 1.0
    print(f"{len(rows)} benchmarks, pass rate {rate:.2%}")
    if rate < a.min_pass_rate:
        raise SystemExit(f"Pass rate {rate:.2%} bajo el mínimo {a.min_pass_rate:.0%}: no promover cambios semánticos")


if __name__ == "__main__":
    main()
