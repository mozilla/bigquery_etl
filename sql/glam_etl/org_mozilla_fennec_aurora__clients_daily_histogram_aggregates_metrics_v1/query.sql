-- Query generated by: python3 -m bigquery_etl.glam.clients_daily_histogram_aggregates --source-table org_mozilla_fennec_aurora_stable.metrics_v1
WITH extracted AS (
  SELECT
    *,
    DATE(submission_timestamp) AS submission_date,
    client_info.client_id,
    "metrics" AS ping_type,
    COALESCE(
      SAFE_CAST(SPLIT(client_info.app_display_version, '.')[OFFSET(0)] AS INT64),
      0
    ) AS app_version,
    client_info.os AS os,
    client_info.app_build AS app_build_id,
    client_info.app_channel AS channel
  FROM
    `moz-fx-data-shared-prod.org_mozilla_fennec_aurora_stable.metrics_v1`
  WHERE
    DATE(submission_timestamp) = @submission_date
    AND client_info.client_id IS NOT NULL
),
histograms AS (
  SELECT
    sample_id,
    client_id,
    ping_type,
    submission_date,
    os,
    app_version,
    app_build_id,
    channel,
    ARRAY<STRUCT<metric STRING, metric_type STRING, value ARRAY<STRUCT<key STRING, value INT64>>>>[
      (
        "geckoview_content_process_lifetime",
        "timing_distribution",
        metrics.timing_distribution.geckoview_content_process_lifetime.values
      ),
      (
        "geckoview_document_site_origins",
        "custom_distribution",
        metrics.custom_distribution.geckoview_document_site_origins.values
      ),
      (
        "geckoview_page_load_progress_time",
        "timing_distribution",
        metrics.timing_distribution.geckoview_page_load_progress_time.values
      ),
      (
        "geckoview_page_load_time",
        "timing_distribution",
        metrics.timing_distribution.geckoview_page_load_time.values
      ),
      (
        "geckoview_page_reload_time",
        "timing_distribution",
        metrics.timing_distribution.geckoview_page_reload_time.values
      ),
      (
        "geckoview_per_document_site_origins",
        "custom_distribution",
        metrics.custom_distribution.geckoview_per_document_site_origins.values
      ),
      (
        "geckoview_startup_runtime",
        "timing_distribution",
        metrics.timing_distribution.geckoview_startup_runtime.values
      ),
      (
        "gfx_checkerboard_duration",
        "timing_distribution",
        metrics.timing_distribution.gfx_checkerboard_duration.values
      ),
      (
        "gfx_checkerboard_peak_pixel_count",
        "custom_distribution",
        metrics.custom_distribution.gfx_checkerboard_peak_pixel_count.values
      ),
      (
        "gfx_checkerboard_potential_duration",
        "timing_distribution",
        metrics.timing_distribution.gfx_checkerboard_potential_duration.values
      ),
      (
        "gfx_checkerboard_severity",
        "custom_distribution",
        metrics.custom_distribution.gfx_checkerboard_severity.values
      ),
      (
        "gfx_composite_time",
        "timing_distribution",
        metrics.timing_distribution.gfx_composite_time.values
      ),
      (
        "gfx_content_frame_time_from_paint",
        "custom_distribution",
        metrics.custom_distribution.gfx_content_frame_time_from_paint.values
      ),
      (
        "gfx_content_frame_time_from_vsync",
        "custom_distribution",
        metrics.custom_distribution.gfx_content_frame_time_from_vsync.values
      ),
      (
        "gfx_content_frame_time_with_svg",
        "custom_distribution",
        metrics.custom_distribution.gfx_content_frame_time_with_svg.values
      ),
      (
        "gfx_content_frame_time_without_resource_upload",
        "custom_distribution",
        metrics.custom_distribution.gfx_content_frame_time_without_resource_upload.values
      ),
      (
        "gfx_content_frame_time_without_upload",
        "custom_distribution",
        metrics.custom_distribution.gfx_content_frame_time_without_upload.values
      ),
      (
        "gfx_content_full_paint_time",
        "timing_distribution",
        metrics.timing_distribution.gfx_content_full_paint_time.values
      ),
      (
        "gfx_content_paint_time",
        "timing_distribution",
        metrics.timing_distribution.gfx_content_paint_time.values
      ),
      (
        "gfx_scroll_present_latency",
        "timing_distribution",
        metrics.timing_distribution.gfx_scroll_present_latency.values
      ),
      (
        "gfx_status_framebuild_time",
        "timing_distribution",
        metrics.timing_distribution.gfx_status_framebuild_time.values
      ),
      (
        "gfx_status_sceneswap_time",
        "timing_distribution",
        metrics.timing_distribution.gfx_status_sceneswap_time.values
      ),
      (
        "gfx_webrender_framebuild_time",
        "timing_distribution",
        metrics.timing_distribution.gfx_webrender_framebuild_time.values
      ),
      (
        "gfx_webrender_render_time",
        "timing_distribution",
        metrics.timing_distribution.gfx_webrender_render_time.values
      ),
      (
        "gfx_webrender_scenebuild_time",
        "timing_distribution",
        metrics.timing_distribution.gfx_webrender_scenebuild_time.values
      ),
      (
        "gfx_webrender_sceneswap_time",
        "timing_distribution",
        metrics.timing_distribution.gfx_webrender_sceneswap_time.values
      ),
      (
        "javascript_gc_compact_time",
        "timing_distribution",
        metrics.timing_distribution.javascript_gc_compact_time.values
      ),
      (
        "javascript_gc_mark_roots_time",
        "timing_distribution",
        metrics.timing_distribution.javascript_gc_mark_roots_time.values
      ),
      (
        "javascript_gc_mark_time",
        "timing_distribution",
        metrics.timing_distribution.javascript_gc_mark_time.values
      ),
      (
        "javascript_gc_minor_time",
        "timing_distribution",
        metrics.timing_distribution.javascript_gc_minor_time.values
      ),
      (
        "javascript_gc_prepare_time",
        "timing_distribution",
        metrics.timing_distribution.javascript_gc_prepare_time.values
      ),
      (
        "javascript_gc_slice_time",
        "timing_distribution",
        metrics.timing_distribution.javascript_gc_slice_time.values
      ),
      (
        "javascript_gc_sweep_time",
        "timing_distribution",
        metrics.timing_distribution.javascript_gc_sweep_time.values
      ),
      (
        "javascript_gc_total_time",
        "timing_distribution",
        metrics.timing_distribution.javascript_gc_total_time.values
      ),
      (
        "logins_store_read_query_time",
        "timing_distribution",
        metrics.timing_distribution.logins_store_read_query_time.values
      ),
      (
        "logins_store_unlock_time",
        "timing_distribution",
        metrics.timing_distribution.logins_store_unlock_time.values
      ),
      (
        "logins_store_write_query_time",
        "timing_distribution",
        metrics.timing_distribution.logins_store_write_query_time.values
      ),
      (
        "network_cache_hit_time",
        "timing_distribution",
        metrics.timing_distribution.network_cache_hit_time.values
      ),
      (
        "network_dns_end",
        "timing_distribution",
        metrics.timing_distribution.network_dns_end.values
      ),
      (
        "network_dns_start",
        "timing_distribution",
        metrics.timing_distribution.network_dns_start.values
      ),
      (
        "network_first_from_cache",
        "timing_distribution",
        metrics.timing_distribution.network_first_from_cache.values
      ),
      (
        "network_font_download_end",
        "timing_distribution",
        metrics.timing_distribution.network_font_download_end.values
      ),
      (
        "network_tcp_connection",
        "timing_distribution",
        metrics.timing_distribution.network_tcp_connection.values
      ),
      (
        "network_tls_handshake",
        "timing_distribution",
        metrics.timing_distribution.network_tls_handshake.values
      ),
      (
        "perf_awesomebar_bookmark_suggestions",
        "timing_distribution",
        metrics.timing_distribution.perf_awesomebar_bookmark_suggestions.values
      ),
      (
        "perf_awesomebar_clipboard_suggestions",
        "timing_distribution",
        metrics.timing_distribution.perf_awesomebar_clipboard_suggestions.values
      ),
      (
        "perf_awesomebar_history_suggestions",
        "timing_distribution",
        metrics.timing_distribution.perf_awesomebar_history_suggestions.values
      ),
      (
        "perf_awesomebar_search_engine_suggestions",
        "timing_distribution",
        metrics.timing_distribution.perf_awesomebar_search_engine_suggestions.values
      ),
      (
        "perf_awesomebar_session_suggestions",
        "timing_distribution",
        metrics.timing_distribution.perf_awesomebar_session_suggestions.values
      ),
      (
        "perf_awesomebar_shortcuts_suggestions",
        "timing_distribution",
        metrics.timing_distribution.perf_awesomebar_shortcuts_suggestions.values
      ),
      (
        "perf_awesomebar_synced_tabs_suggestions",
        "timing_distribution",
        metrics.timing_distribution.perf_awesomebar_synced_tabs_suggestions.values
      ),
      (
        "performance_interaction_keypress_present_latency",
        "timing_distribution",
        metrics.timing_distribution.performance_interaction_keypress_present_latency.values
      ),
      (
        "performance_interaction_tab_switch_composite",
        "timing_distribution",
        metrics.timing_distribution.performance_interaction_tab_switch_composite.values
      ),
      (
        "performance_page_non_blank_paint",
        "timing_distribution",
        metrics.timing_distribution.performance_page_non_blank_paint.values
      ),
      (
        "performance_page_total_content_page_load",
        "timing_distribution",
        metrics.timing_distribution.performance_page_total_content_page_load.values
      ),
      (
        "performance_time_dom_complete",
        "timing_distribution",
        metrics.timing_distribution.performance_time_dom_complete.values
      ),
      (
        "performance_time_dom_content_loaded_end",
        "timing_distribution",
        metrics.timing_distribution.performance_time_dom_content_loaded_end.values
      ),
      (
        "performance_time_dom_content_loaded_start",
        "timing_distribution",
        metrics.timing_distribution.performance_time_dom_content_loaded_start.values
      ),
      (
        "performance_time_dom_interactive",
        "timing_distribution",
        metrics.timing_distribution.performance_time_dom_interactive.values
      ),
      (
        "performance_time_load_event_end",
        "timing_distribution",
        metrics.timing_distribution.performance_time_load_event_end.values
      ),
      (
        "performance_time_load_event_start",
        "timing_distribution",
        metrics.timing_distribution.performance_time_load_event_start.values
      ),
      (
        "performance_time_response_start",
        "timing_distribution",
        metrics.timing_distribution.performance_time_response_start.values
      ),
      (
        "places_manager_read_query_time",
        "timing_distribution",
        metrics.timing_distribution.places_manager_read_query_time.values
      ),
      (
        "places_manager_scan_query_time",
        "timing_distribution",
        metrics.timing_distribution.places_manager_scan_query_time.values
      ),
      (
        "places_manager_write_query_time",
        "timing_distribution",
        metrics.timing_distribution.places_manager_write_query_time.values
      )
    ] AS metadata
  FROM
    extracted
),
flattened_histograms AS (
  SELECT
    sample_id,
    client_id,
    ping_type,
    submission_date,
    os,
    app_version,
    app_build_id,
    channel,
    metadata.*
  FROM
    histograms,
    UNNEST(metadata) AS metadata
  WHERE
    value IS NOT NULL
),
-- ARRAY_CONCAT_AGG may fail if the array of records exceeds 20 MB when
-- serialized and shuffled. This may exhibit itself in a pathological case where
-- the a single client sends *many* pings in a single day. However, this case
-- has not been observed. If this does occur, each histogram should be unnested
-- aggregated. This will force more shuffles and is inefficient. This may be
-- mitigated by removing all of the empty entries which are sent to keep bucket
-- ranges contiguous.
--
-- Tested via org_mozilla_fenix.metrics_v1 for 2020-02-23, unnest vs concat
-- Slot consumed: 00:50:15 vs 00:06:45, Shuffled: 27.5GB vs 6.0 GB
aggregated AS (
  SELECT
    sample_id,
    client_id,
    ping_type,
    submission_date,
    os,
    app_version,
    app_build_id,
    channel,
    metric,
    metric_type,
    `moz-fx-data-shared-prod`.udf.map_sum(ARRAY_CONCAT_AGG(value)) AS value
  FROM
    flattened_histograms
  GROUP BY
    sample_id,
    client_id,
    ping_type,
    submission_date,
    os,
    app_version,
    app_build_id,
    channel,
    metric,
    metric_type
)
SELECT
  sample_id,
  client_id,
  ping_type,
  submission_date,
  os,
  app_version,
  app_build_id,
  channel,
  ARRAY_AGG(
    STRUCT<
      metric STRING,
      metric_type STRING,
      key STRING,
      agg_type STRING,
      value ARRAY<STRUCT<key STRING, value INT64>>
    >(metric, metric_type, '', 'summed_histogram', value)
  ) AS histogram_aggregates
FROM
  aggregated
GROUP BY
  sample_id,
  client_id,
  ping_type,
  submission_date,
  os,
  app_version,
  app_build_id,
  channel
