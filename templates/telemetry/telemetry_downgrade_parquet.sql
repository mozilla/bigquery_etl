CREATE OR REPLACE VIEW
  `moz-fx-data-derived-datasets.telemetry.telemetry_downgrade_parquet`
AS SELECT * FROM
  `moz-fx-data-derived-datasets.telemetry_derived.telemetry_downgrade_parquet_v1`
