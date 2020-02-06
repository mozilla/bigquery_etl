-- Query generated by: python3 -m bigquery_etl.glam.glean_scalar_aggregates --agg-type keyed_scalars --table-id org_mozilla_fenix_stable.migration_v1
WITH filtered AS (
  SELECT
    *,
    DATE(submission_timestamp) AS submission_date,
    client_info.client_id,
    SPLIT(client_info.app_display_version, '.')[OFFSET(0)] AS app_version,
    client_info.os AS os,
    client_info.app_build AS app_build_id,
    client_info.app_channel AS channel
  FROM
    `moz-fx-data-shared-prod.org_mozilla_fenix_stable.migration_v1`
  WHERE
    DATE(submission_timestamp) = @submission_date
    AND client_info.app_channel IN ("release", "fenixProduction")
    AND client_info.client_id IS NOT NULL
),
grouped_metrics AS (
  SELECT
    client_id,
    submission_date,
    os,
    app_version,
    app_build_id,
    channel,
    ARRAY<STRUCT<name STRING, type STRING, value ARRAY<STRUCT<key STRING, value INT64>>>>[
      (
        'glean_error_invalid_label',
        'labeled_counter',
        metrics.labeled_counter.glean_error_invalid_label
      ),
      (
        'glean_error_invalid_overflow',
        'labeled_counter',
        metrics.labeled_counter.glean_error_invalid_overflow
      ),
      (
        'glean_error_invalid_state',
        'labeled_counter',
        metrics.labeled_counter.glean_error_invalid_state
      ),
      (
        'glean_error_invalid_value',
        'labeled_counter',
        metrics.labeled_counter.glean_error_invalid_value
      ),
      (
        'migration_bookmarks_migrated',
        'labeled_counter',
        metrics.labeled_counter.migration_bookmarks_migrated
      ),
      (
        'migration_history_migrated',
        'labeled_counter',
        metrics.labeled_counter.migration_history_migrated
      ),
      (
        'migration_logins_failure_counts',
        'labeled_counter',
        metrics.labeled_counter.migration_logins_failure_counts
      )
    ] AS metrics
  FROM
    filtered
),
flattened_metrics AS (
  SELECT
    client_id,
    submission_date,
    os,
    app_version,
    app_build_id,
    channel,
    metrics.name AS metric,
    metrics.type AS metric_type,
    value.key AS key,
    value.value AS value
  FROM
    grouped_metrics
  CROSS JOIN
    UNNEST(metrics) AS metrics,
    UNNEST(metrics.value) AS value
),
aggregated AS (
  SELECT
    client_id,
    submission_date,
    os,
    app_version,
    app_build_id,
    channel,
    metric,
    metric_type,
    key,
    MAX(value) AS max,
    MIN(value) AS min,
    AVG(value) AS avg,
    SUM(value) AS sum,
    IF(MIN(value) IS NULL, NULL, COUNT(*)) AS count
  FROM
    flattened_metrics
  GROUP BY
    client_id,
    submission_date,
    os,
    app_version,
    app_build_id,
    channel,
    metric,
    metric_type,
    key
)
SELECT
  client_id,
  submission_date,
  os,
  app_version,
  app_build_id,
  channel,
  ARRAY_CONCAT_AGG(
    ARRAY<STRUCT<metric STRING, metric_type STRING, key STRING, agg_type STRING, value FLOAT64>>[
      (metric, metric_type, key, 'max', max),
      (metric, metric_type, key, 'min', min),
      (metric, metric_type, key, 'avg', avg),
      (metric, metric_type, key, 'sum', sum),
      (metric, metric_type, key, 'count', count)
    ]
  ) AS scalar_aggregates
FROM
  aggregated
GROUP BY
  client_id,
  submission_date,
  os,
  app_version,
  app_build_id,
  channel
