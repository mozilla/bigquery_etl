
--
-- Query generated by: templates/unnest_parquet_view.sql.py telemetry_mobile_event_parquet_v2 telemetry_raw.telemetry_mobile_event_parquet_v2
CREATE OR REPLACE VIEW
  `moz-fx-data-derived-datasets.telemetry.telemetry_mobile_event_parquet_v2` AS
SELECT
  submission_date AS submission_date_s3,
  * REPLACE (
    ARRAY(SELECT AS STRUCT _0.element.* REPLACE (_0.element.extra.key_value AS extra) FROM UNNEST(events.list) AS _0) AS events,
    experiments.key_value AS experiments,
    settings.key_value AS settings
  )
FROM
  `moz-fx-data-derived-datasets.telemetry_raw.telemetry_mobile_event_parquet_v2`
