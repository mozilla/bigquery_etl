WITH distinct_countries AS (
  -- Some country codes appear multiple times as some countries have multiple names.
  -- Ensure that each code appears only once and go with name that appears first.
  SELECT
    code,
    name
  FROM
    (
      SELECT
        row_number() OVER (PARTITION BY code ORDER BY name) AS rn,
        code,
        name
      FROM
        `moz-fx-data-derived-datasets`.static.country_names_v1 country_names
    )
  WHERE
    rn = 1
)
SELECT
  DATE(submission_timestamp) AS date,
  country_names.name AS country_name,
  normalized_channel AS channel,
  application.build_id AS build_id,
  normalized_os AS os,
  environment.settings.attribution.source AS attribution_source,
  environment.partner.distribution_id AS distribution_id,
  coalesce(environment.settings.attribution.ua, '') AS attribution_ua,
  COUNT(DISTINCT client_id) AS new_profiles,
FROM
  telemetry.new_profile
LEFT JOIN
  distinct_countries country_names
ON
  (country_names.code = normalized_country_code)
WHERE
  DATE(submission_timestamp) = @submission_date
  AND payload.processes.parent.scalars.startup_profile_selection_reason = 'firstrun-created-default'
GROUP BY
  date,
  country_name,
  channel,
  build_id,
  os,
  attribution_source,
  distribution_id,
  attribution_ua
