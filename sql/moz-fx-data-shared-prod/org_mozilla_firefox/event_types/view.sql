-- Generated by bigquery_etl/events_daily/generate_queries.py
CREATE OR REPLACE VIEW
  `moz-fx-data-shared-prod.org_mozilla_firefox.event_types`
AS
SELECT
  *
FROM
  `moz-fx-data-shared-prod.org_mozilla_firefox_derived.event_types_v1`
