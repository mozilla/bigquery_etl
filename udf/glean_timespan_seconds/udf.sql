-- Legacy wrapper around a function moved to mozfun.
CREATE OR REPLACE FUNCTION udf.glean_timespan_seconds(
  timespan STRUCT<time_unit STRING, value INT64>
) AS (
  mozfun.glean.timespan_seconds(timespan)
);
