-- Query generated by: python3 -m bigquery_etl.glam.glean_scalar_aggregates --agg-type scalars --table-id org_mozilla_fenix_stable.history_sync_v1
WITH filtered AS (
  SELECT
    *,
    DATE(submission_timestamp) AS submission_date,
    client_info.client_id,
    REPLACE(ping_info.ping_type, "_", "-") AS ping_type,
    SPLIT(client_info.app_display_version, '.')[OFFSET(0)] AS app_version,
    client_info.os AS os,
    client_info.app_build AS app_build_id,
    client_info.app_channel AS channel
  FROM
    `moz-fx-data-shared-prod.org_mozilla_fenix_stable.history_sync_v1`
  WHERE
    DATE(submission_timestamp) = @submission_date
    AND client_info.app_channel IN ("release", "fenixProduction")
    AND client_info.client_id IS NOT NULL
),
aggregated AS (
  SELECT
    client_id,
    ping_type,
    submission_date,
    os,
    app_version,
    app_build_id,
    channel,
    ARRAY<STRUCT<metric STRING, metric_type STRING, key STRING, agg_type STRING, value FLOAT64>>[
      (
        'history_sync_outgoing_batches',
        'counter',
        '',
        'avg',
        avg(CAST(metrics.counter.history_sync_outgoing_batches AS INT64))
      ),
      (
        'history_sync_outgoing_batches',
        'counter',
        '',
        'count',
        IF(MIN(metrics.counter.history_sync_outgoing_batches) IS NULL, NULL, COUNT(*))
      ),
      (
        'history_sync_outgoing_batches',
        'counter',
        '',
        'max',
        max(CAST(metrics.counter.history_sync_outgoing_batches AS INT64))
      ),
      (
        'history_sync_outgoing_batches',
        'counter',
        '',
        'min',
        min(CAST(metrics.counter.history_sync_outgoing_batches AS INT64))
      ),
      (
        'history_sync_outgoing_batches',
        'counter',
        '',
        'sum',
        sum(CAST(metrics.counter.history_sync_outgoing_batches AS INT64))
      )
    ] AS scalar_aggregates
  FROM
    filtered
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
  aggregated
