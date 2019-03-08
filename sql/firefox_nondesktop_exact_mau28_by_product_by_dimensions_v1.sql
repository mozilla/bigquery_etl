WITH
  inactive_days AS (
    SELECT
      *,
      DATE_DIFF(submission_date, date_last_seen, DAY) AS _inactive_days,
      DATE_DIFF(submission_date, date_last_seen_in_tier1_country, DAY) AS _inactive_days_tier1
    FROM
      core_clients_last_seen_v1
  )

SELECT
  submission_date,
  CURRENT_DATETIME() AS generated_time,
  COUNTIF(_inactive_days < 28) AS mau,
  COUNTIF(_inactive_days < 7) AS wau,
  COUNTIF(_inactive_days < 1) AS dau,
  -- Instead of app_name and os, we provide a single clean "product" name
  -- that includes OS where necessary to disambiguate.
  CASE app_name
    WHEN 'Fennec' THEN CONCAT(app_name, ' ', os)
    WHEN 'Focus' THEN CONCAT(app_name, ' ', os)
    WHEN 'Zerda' THEN 'Firefox Lite'
    ELSE app_name
  END AS product,
  campaign,
  country,
  distribution_id
FROM
  inactive_days
WHERE
  -- This list corresponds to the products considered for 2019 nondesktop KPIs.
  app_name IN (
    'Fennec', -- Firefox for Android and Firefox for iOS
    'Focus',
    'Zerda', -- Firefox Lite, previously called Rocket
    'FirefoxForFireTV', -- Amazon Fire TV
    'FirefoxConnect' -- Amazon Echo Show
    )
  AND os IN ('Android', 'iOS')
  AND normalized_channel = 'release'
  -- 2017-01-01 is the first populated day of telemetry_core_parquet, so start 28 days later.
  AND @submission_date >= '2017-01-28'
  AND @submission_date = submission_date
GROUP BY
  submission_date,
  product,
  campaign,
  country,
  distribution_id
