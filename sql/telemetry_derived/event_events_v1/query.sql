-- Creates a backwards-compatible flattened events dataset created from gcp-ingested event pings
-- Designed to provide continuity for the `events` dataset via a user-facing union view
SELECT
  DATE(submission_timestamp) AS submission_date,
  document_id,
  client_id,
  normalized_channel,
  normalized_country_code AS country,
  metadata.geo.city,
  environment.settings.locale AS locale,
  normalized_app_name AS app_name,
  metadata.uri.app_version AS app_version,
  normalized_os AS os,
  normalized_os_version AS os_version,
  environment.settings.attribution.source AS attribution_source,
  application.build_id,
  environment.build.architecture AS build_architecture,
  environment.settings.is_default_browser,
  environment.profile.creation_date AS profile_creation_date,
  environment.system.is_wow64 AS system_is_wow64,
  environment.system.memory_mb AS system_memory_mb,
  environment.experiments AS experiments,
  sample_id,
  payload.session_id AS session_id,
  SAFE.TIMESTAMP_MILLIS(payload.process_start_timestamp) AS session_start_time,
  payload.subsession_id AS subsession_id,
  submission_timestamp AS `timestamp`,
  udf.deanonymize_event(e).*,
  event_process
FROM
  telemetry.event
CROSS JOIN
  UNNEST(
    [
      STRUCT(
        "content" AS event_process,
        payload.events.content AS events
      ),
      ("dynamic", payload.events.dynamic),
      ("extension", payload.events.extension),
      ("gpu", payload.events.gpu),
      ("parent", payload.events.parent)
    ]
  )
CROSS JOIN
  UNNEST(events) AS e
WHERE
  date(submission_timestamp) = @submission_date
