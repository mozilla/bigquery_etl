        -- Query generated by:
        -- python3 -m bigquery_etl.glam.glean_scalar_aggregates --agg-type scalars
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
    `moz-fx-data-shared-prod.org_mozilla_fenix_stable.metrics_v1`
  WHERE
    DATE(submission_timestamp) = @submission_date
    AND client_info.app_channel IN ("release", "fenixProduction")
    AND client_info.client_id IS NOT NULL
),
aggregated AS (
  SELECT
    client_id,
    submission_date,
    os,
    app_version,
    app_build_id,
    channel,
    ARRAY<STRUCT<metric STRING, metric_type STRING, key STRING, agg_type STRING, value FLOAT64>>[
      (
        'events_total_uri_count',
        'counter',
        '',
        'avg',
        avg(CAST(metrics.counter.events_total_uri_count AS INT64))
      ),
      (
        'events_total_uri_count',
        'counter',
        '',
        'count',
        IF(MIN(metrics.counter.events_total_uri_count) IS NULL, NULL, COUNT(*))
      ),
      (
        'events_total_uri_count',
        'counter',
        '',
        'max',
        max(CAST(metrics.counter.events_total_uri_count AS INT64))
      ),
      (
        'events_total_uri_count',
        'counter',
        '',
        'min',
        min(CAST(metrics.counter.events_total_uri_count AS INT64))
      ),
      (
        'events_total_uri_count',
        'counter',
        '',
        'sum',
        sum(CAST(metrics.counter.events_total_uri_count AS INT64))
      ),
      (
        'gfx_adapter_primary_ram',
        'quantity',
        '',
        'avg',
        avg(CAST(metrics.quantity.gfx_adapter_primary_ram AS INT64))
      ),
      (
        'gfx_adapter_primary_ram',
        'quantity',
        '',
        'count',
        IF(MIN(metrics.quantity.gfx_adapter_primary_ram) IS NULL, NULL, COUNT(*))
      ),
      (
        'gfx_adapter_primary_ram',
        'quantity',
        '',
        'max',
        max(CAST(metrics.quantity.gfx_adapter_primary_ram AS INT64))
      ),
      (
        'gfx_adapter_primary_ram',
        'quantity',
        '',
        'min',
        min(CAST(metrics.quantity.gfx_adapter_primary_ram AS INT64))
      ),
      (
        'gfx_adapter_primary_ram',
        'quantity',
        '',
        'sum',
        sum(CAST(metrics.quantity.gfx_adapter_primary_ram AS INT64))
      ),
      (
        'gfx_display_count',
        'quantity',
        '',
        'avg',
        avg(CAST(metrics.quantity.gfx_display_count AS INT64))
      ),
      (
        'gfx_display_count',
        'quantity',
        '',
        'count',
        IF(MIN(metrics.quantity.gfx_display_count) IS NULL, NULL, COUNT(*))
      ),
      (
        'gfx_display_count',
        'quantity',
        '',
        'max',
        max(CAST(metrics.quantity.gfx_display_count AS INT64))
      ),
      (
        'gfx_display_count',
        'quantity',
        '',
        'min',
        min(CAST(metrics.quantity.gfx_display_count AS INT64))
      ),
      (
        'gfx_display_count',
        'quantity',
        '',
        'sum',
        sum(CAST(metrics.quantity.gfx_display_count AS INT64))
      ),
      (
        'gfx_display_primary_height',
        'quantity',
        '',
        'avg',
        avg(CAST(metrics.quantity.gfx_display_primary_height AS INT64))
      ),
      (
        'gfx_display_primary_height',
        'quantity',
        '',
        'count',
        IF(MIN(metrics.quantity.gfx_display_primary_height) IS NULL, NULL, COUNT(*))
      ),
      (
        'gfx_display_primary_height',
        'quantity',
        '',
        'max',
        max(CAST(metrics.quantity.gfx_display_primary_height AS INT64))
      ),
      (
        'gfx_display_primary_height',
        'quantity',
        '',
        'min',
        min(CAST(metrics.quantity.gfx_display_primary_height AS INT64))
      ),
      (
        'gfx_display_primary_height',
        'quantity',
        '',
        'sum',
        sum(CAST(metrics.quantity.gfx_display_primary_height AS INT64))
      ),
      (
        'gfx_display_primary_width',
        'quantity',
        '',
        'avg',
        avg(CAST(metrics.quantity.gfx_display_primary_width AS INT64))
      ),
      (
        'gfx_display_primary_width',
        'quantity',
        '',
        'count',
        IF(MIN(metrics.quantity.gfx_display_primary_width) IS NULL, NULL, COUNT(*))
      ),
      (
        'gfx_display_primary_width',
        'quantity',
        '',
        'max',
        max(CAST(metrics.quantity.gfx_display_primary_width AS INT64))
      ),
      (
        'gfx_display_primary_width',
        'quantity',
        '',
        'min',
        min(CAST(metrics.quantity.gfx_display_primary_width AS INT64))
      ),
      (
        'gfx_display_primary_width',
        'quantity',
        '',
        'sum',
        sum(CAST(metrics.quantity.gfx_display_primary_width AS INT64))
      ),
      (
        'gfx_status_headless',
        'boolean',
        '',
        'false',
        SUM(CASE WHEN metrics.boolean.gfx_status_headless = FALSE THEN 1 ELSE 0 END)
      ),
      (
        'gfx_status_headless',
        'boolean',
        '',
        'true',
        SUM(CASE WHEN metrics.boolean.gfx_status_headless = TRUE THEN 1 ELSE 0 END)
      ),
      (
        'glean_core_migration_successful',
        'boolean',
        '',
        'false',
        SUM(CASE WHEN metrics.boolean.glean_core_migration_successful = FALSE THEN 1 ELSE 0 END)
      ),
      (
        'glean_core_migration_successful',
        'boolean',
        '',
        'true',
        SUM(CASE WHEN metrics.boolean.glean_core_migration_successful = TRUE THEN 1 ELSE 0 END)
      ),
      (
        'glean_error_preinit_tasks_overflow',
        'counter',
        '',
        'avg',
        avg(CAST(metrics.counter.glean_error_preinit_tasks_overflow AS INT64))
      ),
      (
        'glean_error_preinit_tasks_overflow',
        'counter',
        '',
        'count',
        IF(MIN(metrics.counter.glean_error_preinit_tasks_overflow) IS NULL, NULL, COUNT(*))
      ),
      (
        'glean_error_preinit_tasks_overflow',
        'counter',
        '',
        'max',
        max(CAST(metrics.counter.glean_error_preinit_tasks_overflow AS INT64))
      ),
      (
        'glean_error_preinit_tasks_overflow',
        'counter',
        '',
        'min',
        min(CAST(metrics.counter.glean_error_preinit_tasks_overflow AS INT64))
      ),
      (
        'glean_error_preinit_tasks_overflow',
        'counter',
        '',
        'sum',
        sum(CAST(metrics.counter.glean_error_preinit_tasks_overflow AS INT64))
      ),
      (
        'glean_error_preinit_tasks_timeout',
        'boolean',
        '',
        'false',
        SUM(CASE WHEN metrics.boolean.glean_error_preinit_tasks_timeout = FALSE THEN 1 ELSE 0 END)
      ),
      (
        'glean_error_preinit_tasks_timeout',
        'boolean',
        '',
        'true',
        SUM(CASE WHEN metrics.boolean.glean_error_preinit_tasks_timeout = TRUE THEN 1 ELSE 0 END)
      ),
      (
        'glean_validation_app_forceclosed_count',
        'counter',
        '',
        'avg',
        avg(CAST(metrics.counter.glean_validation_app_forceclosed_count AS INT64))
      ),
      (
        'glean_validation_app_forceclosed_count',
        'counter',
        '',
        'count',
        IF(MIN(metrics.counter.glean_validation_app_forceclosed_count) IS NULL, NULL, COUNT(*))
      ),
      (
        'glean_validation_app_forceclosed_count',
        'counter',
        '',
        'max',
        max(CAST(metrics.counter.glean_validation_app_forceclosed_count AS INT64))
      ),
      (
        'glean_validation_app_forceclosed_count',
        'counter',
        '',
        'min',
        min(CAST(metrics.counter.glean_validation_app_forceclosed_count AS INT64))
      ),
      (
        'glean_validation_app_forceclosed_count',
        'counter',
        '',
        'sum',
        sum(CAST(metrics.counter.glean_validation_app_forceclosed_count AS INT64))
      ),
      (
        'glean_validation_baseline_ping_count',
        'counter',
        '',
        'avg',
        avg(CAST(metrics.counter.glean_validation_baseline_ping_count AS INT64))
      ),
      (
        'glean_validation_baseline_ping_count',
        'counter',
        '',
        'count',
        IF(MIN(metrics.counter.glean_validation_baseline_ping_count) IS NULL, NULL, COUNT(*))
      ),
      (
        'glean_validation_baseline_ping_count',
        'counter',
        '',
        'max',
        max(CAST(metrics.counter.glean_validation_baseline_ping_count AS INT64))
      ),
      (
        'glean_validation_baseline_ping_count',
        'counter',
        '',
        'min',
        min(CAST(metrics.counter.glean_validation_baseline_ping_count AS INT64))
      ),
      (
        'glean_validation_baseline_ping_count',
        'counter',
        '',
        'sum',
        sum(CAST(metrics.counter.glean_validation_baseline_ping_count AS INT64))
      ),
      (
        'logins_store_read_query_count',
        'counter',
        '',
        'avg',
        avg(CAST(metrics.counter.logins_store_read_query_count AS INT64))
      ),
      (
        'logins_store_read_query_count',
        'counter',
        '',
        'count',
        IF(MIN(metrics.counter.logins_store_read_query_count) IS NULL, NULL, COUNT(*))
      ),
      (
        'logins_store_read_query_count',
        'counter',
        '',
        'max',
        max(CAST(metrics.counter.logins_store_read_query_count AS INT64))
      ),
      (
        'logins_store_read_query_count',
        'counter',
        '',
        'min',
        min(CAST(metrics.counter.logins_store_read_query_count AS INT64))
      ),
      (
        'logins_store_read_query_count',
        'counter',
        '',
        'sum',
        sum(CAST(metrics.counter.logins_store_read_query_count AS INT64))
      ),
      (
        'logins_store_unlock_count',
        'counter',
        '',
        'avg',
        avg(CAST(metrics.counter.logins_store_unlock_count AS INT64))
      ),
      (
        'logins_store_unlock_count',
        'counter',
        '',
        'count',
        IF(MIN(metrics.counter.logins_store_unlock_count) IS NULL, NULL, COUNT(*))
      ),
      (
        'logins_store_unlock_count',
        'counter',
        '',
        'max',
        max(CAST(metrics.counter.logins_store_unlock_count AS INT64))
      ),
      (
        'logins_store_unlock_count',
        'counter',
        '',
        'min',
        min(CAST(metrics.counter.logins_store_unlock_count AS INT64))
      ),
      (
        'logins_store_unlock_count',
        'counter',
        '',
        'sum',
        sum(CAST(metrics.counter.logins_store_unlock_count AS INT64))
      ),
      (
        'logins_store_write_query_count',
        'counter',
        '',
        'avg',
        avg(CAST(metrics.counter.logins_store_write_query_count AS INT64))
      ),
      (
        'logins_store_write_query_count',
        'counter',
        '',
        'count',
        IF(MIN(metrics.counter.logins_store_write_query_count) IS NULL, NULL, COUNT(*))
      ),
      (
        'logins_store_write_query_count',
        'counter',
        '',
        'max',
        max(CAST(metrics.counter.logins_store_write_query_count AS INT64))
      ),
      (
        'logins_store_write_query_count',
        'counter',
        '',
        'min',
        min(CAST(metrics.counter.logins_store_write_query_count AS INT64))
      ),
      (
        'logins_store_write_query_count',
        'counter',
        '',
        'sum',
        sum(CAST(metrics.counter.logins_store_write_query_count AS INT64))
      ),
      (
        'metrics_default_browser',
        'boolean',
        '',
        'false',
        SUM(CASE WHEN metrics.boolean.metrics_default_browser = FALSE THEN 1 ELSE 0 END)
      ),
      (
        'metrics_default_browser',
        'boolean',
        '',
        'true',
        SUM(CASE WHEN metrics.boolean.metrics_default_browser = TRUE THEN 1 ELSE 0 END)
      )
    ] AS scalar_aggregates
  FROM
    filtered
  GROUP BY
    client_id,
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
