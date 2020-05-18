-- Query generated by: python3 -m bigquery_etl.glam.clients_daily_scalar_aggregates --source-table org_mozilla_fenix_stable.metrics_v1
WITH extracted AS (
  SELECT
    *,
    DATE(submission_timestamp) AS submission_date,
    client_info.client_id,
    REPLACE(ping_info.ping_type, "_", "-") AS ping_type,
    COALESCE(
      SAFE_CAST(SPLIT(client_info.app_display_version, '.')[OFFSET(0)] AS INT64),
      0
    ) AS app_version,
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
      (
        'addons_has_enabled_addons',
        'boolean',
        '',
        'false',
        SUM(CAST(NOT metrics.boolean.addons_has_enabled_addons AS INT64))
      ),
      (
        'addons_has_enabled_addons',
        'boolean',
        '',
        'true',
        SUM(CAST(metrics.boolean.addons_has_enabled_addons AS INT64))
      ),
      (
        'addons_has_installed_addons',
        'boolean',
        '',
        'false',
        SUM(CAST(NOT metrics.boolean.addons_has_installed_addons AS INT64))
      ),
      (
        'addons_has_installed_addons',
        'boolean',
        '',
        'true',
        SUM(CAST(metrics.boolean.addons_has_installed_addons AS INT64))
      ),
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
        SUM(CAST(NOT metrics.boolean.gfx_status_headless AS INT64))
      ),
      (
        'gfx_status_headless',
        'boolean',
        '',
        'true',
        SUM(CAST(metrics.boolean.gfx_status_headless AS INT64))
      ),
      (
        'glean_core_migration_successful',
        'boolean',
        '',
        'false',
        SUM(CAST(NOT metrics.boolean.glean_core_migration_successful AS INT64))
      ),
      (
        'glean_core_migration_successful',
        'boolean',
        '',
        'true',
        SUM(CAST(metrics.boolean.glean_core_migration_successful AS INT64))
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
        SUM(CAST(NOT metrics.boolean.glean_error_preinit_tasks_timeout AS INT64))
      ),
      (
        'glean_error_preinit_tasks_timeout',
        'boolean',
        '',
        'true',
        SUM(CAST(metrics.boolean.glean_error_preinit_tasks_timeout AS INT64))
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
        SUM(CAST(NOT metrics.boolean.metrics_default_browser AS INT64))
      ),
      (
        'metrics_default_browser',
        'boolean',
        '',
        'true',
        SUM(CAST(metrics.boolean.metrics_default_browser AS INT64))
      ),
      (
        'metrics_has_top_sites',
        'boolean',
        '',
        'false',
        SUM(CAST(NOT metrics.boolean.metrics_has_top_sites AS INT64))
      ),
      (
        'metrics_has_top_sites',
        'boolean',
        '',
        'true',
        SUM(CAST(metrics.boolean.metrics_has_top_sites AS INT64))
      ),
      (
        'metrics_top_sites_count',
        'counter',
        '',
        'avg',
        avg(CAST(metrics.counter.metrics_top_sites_count AS INT64))
      ),
      (
        'metrics_top_sites_count',
        'counter',
        '',
        'count',
        IF(MIN(metrics.counter.metrics_top_sites_count) IS NULL, NULL, COUNT(*))
      ),
      (
        'metrics_top_sites_count',
        'counter',
        '',
        'max',
        max(CAST(metrics.counter.metrics_top_sites_count AS INT64))
      ),
      (
        'metrics_top_sites_count',
        'counter',
        '',
        'min',
        min(CAST(metrics.counter.metrics_top_sites_count AS INT64))
      ),
      (
        'metrics_top_sites_count',
        'counter',
        '',
        'sum',
        sum(CAST(metrics.counter.metrics_top_sites_count AS INT64))
      )
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
        'browser_search_ad_clicks',
        'labeled_counter',
        metrics.labeled_counter.browser_search_ad_clicks
      ),
      (
        'browser_search_in_content',
        'labeled_counter',
        metrics.labeled_counter.browser_search_in_content
      ),
      (
        'browser_search_with_ads',
        'labeled_counter',
        metrics.labeled_counter.browser_search_with_ads
      ),
      (
        'crash_metrics_crash_count',
        'labeled_counter',
        metrics.labeled_counter.crash_metrics_crash_count
      ),
      (
        'gfx_content_frame_time_reason',
        'labeled_counter',
        metrics.labeled_counter.gfx_content_frame_time_reason
      ),
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
        'logins_store_read_query_error_count',
        'labeled_counter',
        metrics.labeled_counter.logins_store_read_query_error_count
      ),
      (
        'logins_store_unlock_error_count',
        'labeled_counter',
        metrics.labeled_counter.logins_store_unlock_error_count
      ),
      (
        'logins_store_write_query_error_count',
        'labeled_counter',
        metrics.labeled_counter.logins_store_write_query_error_count
      ),
      ('metrics_search_count', 'labeled_counter', metrics.labeled_counter.metrics_search_count)
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
