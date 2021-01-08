CREATE OR REPLACE VIEW
  `moz-fx-data-shared-prod.telemetry.experiment_enrollment_daily_active_population`
AS
SELECT
  CAST(date_add(submission_date, INTERVAL 1 day) AS timestamp) AS time,
  experiment_id,
  SUM(active_clients) AS value
FROM
  `moz-fx-data-shared-prod.telemetry_derived.experiments_daily_active_clients_v1`
GROUP BY
  1,
  2
ORDER BY
  1
