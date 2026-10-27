-- G6 / POL-01: certificación del producto DP-01 con el tag NATIVO system.certification_status (H-01).
-- Solo se agrega tras el evidence pack N18 firmado (acta LAB-002, 27-oct-2026: GL-01…GL-14 cumplidos).
-- Para descertificar: cambiar el valor a 'deprecated' por PR (nunca a mano).
ALTER TABLE ${data_catalog}.gold.pagos SET TAGS ('system.certification_status' = 'certified');
