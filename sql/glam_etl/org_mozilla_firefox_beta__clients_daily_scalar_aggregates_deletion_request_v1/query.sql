-- Query generated by: python3 -m bigquery_etl.glam.clients_daily_scalar_aggregates --source-table org_mozilla_firefox_beta_stable.deletion_request_v1
WITH extracted AS (
  SELECT
    *,
    DATE(submission_timestamp) AS submission_date,
    client_info.client_id,
    "deletion-request" AS ping_type,
    COALESCE(
      SAFE_CAST(SPLIT(client_info.app_display_version, '.')[OFFSET(0)] AS INT64),
      0
    ) AS app_version,
    client_info.os AS os,
    client_info.app_build AS app_build_id,
    client_info.app_channel AS channel
  FROM
    `moz-fx-data-shared-prod.org_mozilla_firefox_beta_stable.deletion_request_v1`
  WHERE
    DATE(submission_timestamp) = @submission_date
    AND client_info.client_id IS NOT NULL
),
unlabeled_metrics AS (
  SELECT
    client_id,
    ping_type,
    submission_date,
    os,
    app_version,
    app_build_id,
    channel,
    ARRAY<STRUCT<metric STRING, metric_type STRING, key STRING, agg_type STRING, value FLOAT64>>[
    ] AS scalar_aggregates
  FROM
    extracted
  GROUP BY
    client_id,
    ping_type,
    submission_date,
    os,
    app_version,
    app_build_id,
    channel
),
grouped_labeled_metrics AS (
  SELECT
    client_id,
    ping_type,
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
      )
    ] AS metrics
  FROM
    extracted
),
flattened_labeled_metrics AS (
  SELECT
    client_id,
    ping_type,
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
    grouped_labeled_metrics
  CROSS JOIN
    UNNEST(metrics) AS metrics,
    UNNEST(metrics.value) AS value
),
aggregated_labeled_metrics AS (
  SELECT
    client_id,
    ping_type,
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
    flattened_labeled_metrics
  GROUP BY
    client_id,
    ping_type,
    submission_date,
    os,
    app_version,
    app_build_id,
    channel,
    metric,
    metric_type,
    key
),
labeled_metrics AS (
  SELECT
    client_id,
    ping_type,
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
    aggregated_labeled_metrics
  GROUP BY
    client_id,
    ping_type,
    submission_date,
    os,
    app_version,
    app_build_id,
    channel
)
SELECT
  *
FROM
  unlabeled_metrics
UNION ALL
SELECT
  *
FROM
  labeled_metrics
