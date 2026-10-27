"""Pipeline Lakeflow (Spark Declarative Pipelines) del producto DP-01 — Pagos regionales EC/PE.

landing (CSV PayHub) → bronze.pagos_raw (Auto Loader, crudo) → [vista normalizada + DQ-01/03/04/05]
→ silver.pagos (deduplicado, H-10) → [vista de control DQ-02] → gold.pagos (contrato DP-01 1.1.0).

Corre como sp_etl_pagos (excepción ABAC: ve filas y email sin filtro). Comentarios = glosario 08 (POL-06).
email_hash = SHA-256(salt || lower(email)) con la salt del secret scope gov-lab (ADR-004).
"""
import dlt
from pyspark.sql import Window
from pyspark.sql import functions as F

CAT = spark.conf.get("data_catalog")      # noqa: F821 (spark lo inyecta el runtime del pipeline)
LANDING = spark.conf.get("landing_path")  # noqa: F821

# ponytail: textos duplicados de governance_soft/registry/inventory.business_glossary.yaml; generarlos desde el YAML si crecen.
C = {
    "pago_id": "Identificador único del pago asignado por PayHub. Llave del producto; no se reutiliza.",
    "pais": "País donde se procesó el pago, código ISO 3166-1 alfa-2. Determina la visibilidad de la fila.",
    "email": "Correo electrónico del pagador. Dato personal restringido: enmascarado salvo para el grupo autorizado.",
    "email_hash": "SHA-256 con salt del email normalizado. Seudónimo para contar y cruzar pagadores sin ver el email (ADR-004).",
    "moneda": "Moneda del monto, ISO 4217: USD en Ecuador, PEN en Perú. No sumar montos de monedas distintas.",
    "monto": "Valor del pago en la moneda local, 2 decimales, sin comisiones ni impuestos.",
    "fecha_pago": "Fecha y hora (UTC) en que PayHub autorizó el pago.",
    "_archivo": "Archivo del extracto PayHub de origen (linaje y desempate de correcciones).",
    "_ingest_ts": "Momento de ingesta del registro en bronze.",
}


def _col(name, typ, not_null=False):
    return f"{name} {typ}{' NOT NULL' if not_null else ''} COMMENT '{C[name]}'"


@dlt.table(
    name=f"{CAT}.bronze.pagos_raw",
    comment="Extracto diario crudo de PayHub (SRC-01), sin transformar, más metadatos de ingesta. Solo ETL. Retención 90 días.",
    table_properties={"quality": "bronze"},
)
def pagos_raw():
    return (
        spark.readStream.format("cloudFiles")  # noqa: F821
        .option("cloudFiles.format", "csv")
        .option("header", "true")
        .option("sep", ";")
        .option("cloudFiles.inferColumnTypes", "false")
        .load(LANDING)
        .select("*", F.current_timestamp().alias("_ingest_ts"), F.col("_metadata.file_name").alias("_archivo"))
    )


@dlt.view(name="pagos_normalizados")
@dlt.expect_or_drop("DQ-01 pago_id no nulo", "pago_id IS NOT NULL")
@dlt.expect_or_drop("DQ-03 monto positivo", "monto > 0")
@dlt.expect("DQ-04 monto razonable", "monto <= 50000")
@dlt.expect_or_drop("DQ-05 pais valido", "pais IN ('EC', 'PE')")
def pagos_normalizados():
    email = F.expr("nullif(trim(email), '')")
    salt = F.expr("secret('gov-lab', 'email_hash_salt')")
    return spark.read.table(f"{CAT}.bronze.pagos_raw").select(  # noqa: F821
        F.expr("nullif(trim(pago_id), '')").alias("pago_id"),
        F.upper(F.trim("pais")).alias("pais"),  # ' ec ' → EC (DQ-05 se evalúa ya normalizado)
        email.alias("email"),
        F.when(email.isNotNull(), F.sha2(F.concat(salt, F.lower(email)), 256)).alias("email_hash"),
        F.upper(F.trim("moneda")).alias("moneda"),
        F.col("monto").cast("decimal(12,2)").alias("monto"),
        F.col("fecha_pago").cast("timestamp").alias("fecha_pago"),
        "_archivo",
        "_ingest_ts",
    )


@dlt.table(
    name=f"{CAT}.silver.pagos",
    comment="Pagos depurados y validados (DQ-01, 03, 04, 05), uno por pago_id: gana la corrección del archivo más reciente. Solo ETL.",
    table_properties={"quality": "silver"},
    schema=", ".join([
        _col("pago_id", "STRING", True), _col("pais", "STRING", True), _col("email", "STRING"),
        _col("email_hash", "STRING"), _col("moneda", "STRING"), _col("monto", "DECIMAL(12,2)", True),
        _col("fecha_pago", "TIMESTAMP"), _col("_archivo", "STRING"), _col("_ingest_ts", "TIMESTAMP"),
    ]),
)
def pagos_silver():
    w = Window.partitionBy("pago_id").orderBy(F.col("_archivo").desc(), F.col("_ingest_ts").desc())  # H-10
    return (spark.read.table("pagos_normalizados")  # noqa: F821
            .withColumn("_rn", F.row_number().over(w)).where("_rn = 1").drop("_rn"))


@dlt.view(name="pagos_control_unicidad")
@dlt.expect_or_fail("DQ-02 pago_id unico", "_n = 1")
def pagos_control_unicidad():
    return spark.read.table(f"{CAT}.silver.pagos").withColumn(  # noqa: F821
        "_n", F.count("*").over(Window.partitionBy("pago_id")))


@dlt.table(
    name=f"{CAT}.gold.pagos",
    comment="Pagos procesados por PayHub en Ecuador y Perú, uno por fila, depurados y validados. Producto DP-01. Owner: Pagos Regionales.",
    table_properties={"quality": "gold"},
    schema=", ".join([
        _col("pago_id", "STRING", True), _col("pais", "STRING", True), _col("email", "STRING"),
        _col("email_hash", "STRING"), _col("moneda", "STRING"), _col("monto", "DECIMAL(12,2)", True),
        _col("fecha_pago", "TIMESTAMP", True), "CONSTRAINT pk_pagos PRIMARY KEY (pago_id)",
    ]),
)
def pagos_gold():
    return spark.read.table("pagos_control_unicidad").select(  # noqa: F821
        "pago_id", "pais", "email", "email_hash", "moneda", "monto", "fecha_pago")
