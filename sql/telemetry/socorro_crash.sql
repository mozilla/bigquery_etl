CREATE OR REPLACE VIEW
  `moz-fx-data-shared-prod.telemetry.socorro_crash`
AS SELECT * FROM
  `moz-fx-data-derived-datasets.telemetry_derived.socorro_crash_v2`
