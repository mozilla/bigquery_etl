CREATE OR REPLACE VIEW
  `moz-fx-data-shared-prod.telemetry.sync_summary`
AS SELECT * FROM
  `moz-fx-data-derived-datasets.telemetry_derived.sync_summary_v2`
