-- Generated via bigquery_etl.glean_usage
CREATE OR REPLACE VIEW
  `mozilla_lockbox.baseline_clients_daily`
AS
SELECT
  *
FROM
  `moz-fx-data-shared-prod.mozilla_lockbox_derived.baseline_clients_daily_v1`