-- Query generated by: templates/unnest_parquet_view.sql.py clients_daily_v6 telemetry_derived.clients_daily_v6
CREATE OR REPLACE VIEW
  `moz-fx-data-derived-datasets.telemetry.clients_daily_v6` AS
SELECT
  submission_date AS submission_date_s3,
  * REPLACE (
    ARRAY(SELECT * FROM UNNEST(active_addons.list)) AS active_addons,
    ARRAY(SELECT * FROM UNNEST(environment_settings_intl_accept_languages.list)) AS environment_settings_intl_accept_languages,
    ARRAY(SELECT * FROM UNNEST(environment_settings_intl_app_locales.list)) AS environment_settings_intl_app_locales,
    ARRAY(SELECT * FROM UNNEST(environment_settings_intl_available_locales.list)) AS environment_settings_intl_available_locales,
    ARRAY(SELECT * FROM UNNEST(environment_settings_intl_regional_prefs_locales.list)) AS environment_settings_intl_regional_prefs_locales,
    ARRAY(SELECT * FROM UNNEST(environment_settings_intl_requested_locales.list)) AS environment_settings_intl_requested_locales,
    ARRAY(SELECT * FROM UNNEST(environment_settings_intl_system_locales.list)) AS environment_settings_intl_system_locales,
    experiments.key_value AS experiments,
    scalar_parent_devtools_accessibility_select_accessible_for_node_sum.key_value AS scalar_parent_devtools_accessibility_select_accessible_for_node_sum
  )
FROM
  `moz-fx-data-derived-datasets.telemetry_derived.clients_daily_v6`
