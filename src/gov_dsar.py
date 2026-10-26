"""Job gov_dsar: ejecuta solicitudes de supresión (derecho del titular) aprobadas.

Se dispara cuando cambia privacy.dsar_requests (table update trigger) o a demanda.
Las tablas con datos del titular se declaran con TAG NATIVO:  dsar_subject_key = <columna con el identificador>
(incluir tablas SCD2 e históricas). La solicitud guarda solo el hash SHA-256 del identificador (subject_ref_hash),
nunca el dato personal: el borrado compara sha2(columna, 256) = hash.
CDF y time travel conservan las filas hasta el VACUUM: se registra VACUUM_PENDIENTE y lo cierra gov_retention --vacuum.
"""
from __future__ import annotations

import re

from gov_specs import base_parser

HASH = re.compile(r"^[0-9a-f]{64}$")


def dsar_delete_sql(uc_object: str, key_column: str, subject_hash: str) -> str:
    if not HASH.match(subject_hash or ""):
        raise ValueError("subject_ref_hash debe ser SHA-256 en hexadecimal (64 caracteres)")
    if not key_column.replace("_", "").isalnum():
        raise ValueError(f"columna inválida: {key_column}")
    return f"DELETE FROM {uc_object} WHERE sha2(CAST(`{key_column}` AS STRING), 256) = '{subject_hash}'"


def main() -> None:
    p = base_parser("Supresión de datos del titular (DSAR)")
    a = p.parse_args()
    from pyspark.sql import SparkSession
    from gov_lib import Gov
    spark = SparkSession.builder.getOrCreate()
    gov, c = Gov(spark, a.gov_catalog), a.gov_catalog

    requests = spark.sql(f"""SELECT request_id, subject_ref_hash FROM {c}.privacy.dsar_requests
                             WHERE request_type = 'SUPRESION' AND status = 'APROBADA'""").collect()
    tables = spark.sql("""SELECT concat_ws('.', catalog_name, schema_name, table_name) AS uc_object, tag_value AS key_col
                          FROM system.information_schema.table_tags WHERE tag_name = 'dsar_subject_key'""").collect()
    for r in requests:
        ok = True
        for t in tables:
            sql = dsar_delete_sql(t.uc_object, t.key_col, r.subject_ref_hash)
            res = spark.sql(sql).first()
            rows = int(res["num_affected_rows"]) if res is not None and "num_affected_rows" in res.asDict() else -1
            left = spark.sql(sql.replace("DELETE FROM", "SELECT count(*) AS n FROM", 1)).first()["n"]
            gov.log_dsar_step(r.request_id, t.uc_object, "DELETE", rows, left == 0)
            gov.log_dsar_step(r.request_id, t.uc_object, "VACUUM_PENDIENTE", 0, False)
            ok &= left == 0
        gov.merge("privacy.dsar_requests", ["request_id"], [{"request_id": r.request_id,
                                                              "status": "EJECUTADA" if ok else "REVISAR"}])
        print(f"{r.request_id}: {'ejecutada' if ok else 'quedaron filas, revisar'} en {len(tables)} tablas")


if __name__ == "__main__":
    main()
