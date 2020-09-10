WITH events AS (
  SELECT
    submission_timestamp,
    timestamp,
    category,
    name AS event,
    extra AS event_properties,
    client_info.* EXCEPT (os, os_version),
    metadata.geo.city,
    metadata.geo.country,
    metadata.geo.subdivision1,
    normalized_channel AS channel,
    normalized_os AS os,
    normalized_os_version AS os_version,
    IF(ping_info.experiments IS NULL, NULL, TO_JSON_STRING(ping_info.experiments)) AS experiments
  FROM
    org_mozilla_firefox.events,
    UNNEST(events)
  WHERE
    DATE(submission_timestamp) = @submission_date
    OR (@submission_date IS NULL AND @submission_date >= '2020-01-01')
),
joined AS (
  SELECT
    CONCAT(
      udf.pack_event_properties(events.event_properties, event_types_v1.event_properties),
      index
    ) AS index,
    events.* EXCEPT (category, event, event_properties)
  FROM
    events
  INNER JOIN
    org_mozilla_firefox_derived.event_types_v1 event_types_v1
  USING
    (category, event)
)
SELECT
  DATE(submission_timestamp) AS submission_date,
  client_id,
  CONCAT(STRING_AGG(index, ',' ORDER BY timestamp ASC), ',') AS events,
  -- client info
  mozfun.stats.mode_last(ARRAY_AGG(android_sdk_version)) AS android_sdk_version,
  mozfun.stats.mode_last(ARRAY_AGG(app_build)) AS app_build,
  mozfun.stats.mode_last(ARRAY_AGG(app_channel)) AS app_channel,
  mozfun.stats.mode_last(ARRAY_AGG(app_display_version)) AS app_display_version,
  mozfun.stats.mode_last(ARRAY_AGG(architecture)) AS architecture,
  mozfun.stats.mode_last(ARRAY_AGG(device_manufacturer)) AS device_manufacturer,
  mozfun.stats.mode_last(ARRAY_AGG(device_model)) AS device_model,
  mozfun.stats.mode_last(ARRAY_AGG(first_run_date)) AS first_run_date,
  mozfun.stats.mode_last(ARRAY_AGG(telemetry_sdk_build)) AS telemetry_sdk_build,
  mozfun.stats.mode_last(ARRAY_AGG(locale)) AS locale,
  -- metadata
  mozfun.stats.mode_last(ARRAY_AGG(city)) AS city,
  mozfun.stats.mode_last(ARRAY_AGG(country)) AS country,
  mozfun.stats.mode_last(ARRAY_AGG(subdivision1)) AS subdivision1,
  -- normalized fields
  mozfun.stats.mode_last(ARRAY_AGG(channel)) AS channel,
  mozfun.stats.mode_last(ARRAY_AGG(os)) AS os,
  mozfun.stats.mode_last(ARRAY_AGG(os_version)) AS os_version,
  -- ping info
  mozfun.stats.mode_last(ARRAY_AGG(experiments)) AS experiments
FROM
  joined
GROUP BY
  submission_date,
  client_id
