-- Generated by bigquery_etl/events_daily/generate_queries.py
CREATE OR REPLACE VIEW
  `moz-fx-data-shared-prod.messaging_system.events_daily`
AS
SELECT
  *
FROM
  `moz-fx-data-shared-prod.messaging_system_derived.events_daily_v1`
