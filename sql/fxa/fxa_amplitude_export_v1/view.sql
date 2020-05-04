CREATE OR REPLACE VIEW
  `moz-fx-data-shared-prod.fxa.fxa_amplitude_export_v1`
AS
  WITH
    active_users AS (
      SELECT
        * EXCEPT (
            days_seen_bits
          ) REPLACE (
            udf.unnest_dedupe_nested_array(os_used_week) AS os_used_week,
            udf.unnest_dedupe_nested_array(os_used_month) AS os_used_month
          )
      FROM
        fxa_derived.fxa_amplitude_export_v1
      WHERE
        udf.pos_of_trailing_set_bit(days_seen_bits) = 0
    ),
    active_events AS (
    SELECT
      submission_timestamp,
      user_id,
      insert_id,
      'fxa_activity - active' AS event_type,
      timestamp,
      TO_JSON_STRING(STRUCT(services, oauth_client_ids)) AS event_properties,
      '' AS user_events
    FROM
      active_users
  ),
  user_properties AS (
    SELECT
      submission_timestamp,
      user_id,
      '' AS insert_id,
      '$identify' AS event_type,
      timestamp,
      '' AS event_properties,
    -- $ is not valid for a column name, so edit it into the json string
      REPLACE(
        TO_JSON_STRING(
          STRUCT(
            region,
            country,
            LANGUAGE,
            os_used_day,
            os_used_week,
            os_used_month,
            sync_device_count,
            sync_active_devices_day,
            sync_active_devices_week,
            sync_active_devices_month,
            ua_version,
            ua_browser,
            app_version,
            STRUCT(fxa_services_used) AS str_dollar_sign_postInsert
          )
        ),
        'str_dollar_sign_',
        '$'
      )
    FROM
      active_users
  ),
  all_events AS (
    SELECT
      *
    FROM
      active_events
    UNION ALL
    SELECT
      *
    FROM
      user_properties
  )
SELECT
  *
FROM
  all_events
