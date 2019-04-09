SELECT
  submission_date_s3 AS submission_date,
  sample_id,
  client_id,
  normalized_channel,
  SUBSTR(app_version, 1, 2) AS app_version,
  locale,
  (
  SELECT
    AS STRUCT --
    COUNTIF(is_self_install) AS n_self_installed_addons,
    COUNTIF(_addon.element.addon_id LIKE "%@shield.mozilla%") AS n_shield_addons,
    COUNTIF(_addon.element.foreign_install) AS n_foreign_installed_addons,
    COUNTIF(_addon.element.is_system) AS n_system_addons,
    COUNTIF(_addon.element.is_web_extension) AS n_web_extensions,
    MIN(IF(is_self_install,
        SAFE.DATE_FROM_UNIX_DATE(_addon.element.install_day),
        NULL)) AS first_addon_install_date,
    MIN(SAFE.PARSE_DATE("%Y-%m-%d 00:00:00",
        profile_creation_date)) AS profile_creation_date
  FROM (
    SELECT
      *,
      element.addon_id IS NOT NULL
      AND NOT element.is_system
      AND NOT element.foreign_install
      AND NOT element.addon_id LIKE '%mozilla%'
      AND NOT element.addon_id LIKE '%cliqz%'
      AND NOT element.addon_id LIKE '%@unified-urlbar%' AS is_self_install
    FROM
      UNNEST(active_addons.list)) AS _addon)
FROM
  telemetry.clients_daily_v6
WHERE
  client_id IS NOT NULL
  AND submission_date_s3 = @submission_date
