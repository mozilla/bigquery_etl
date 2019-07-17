-- Query generated by: sql/smoot_usage_raw.sql.py --source clients_last_seen_v1

WITH
  base AS (
    SELECT
      * EXCEPT(channel, normalized_channel),
      normalized_channel AS channel
    FROM
      clients_last_seen_v1)
  --
SELECT
  submission_date,
  COUNTIF(days_since_created_profile = 6) AS new_profiles,
  [ --
  STRUCT('Any Firefox Desktop Activity' AS usage,
    STRUCT(
      COUNTIF(days_since_seen < 1) AS dau,
      COUNTIF(days_since_seen < 7) AS wau,
      COUNTIF(days_since_seen < 28) AS mau,
      SUM(udf_bitcount_lowest_7(days_seen_bits)) AS active_days_in_week
    ) AS metrics_daily,
    STRUCT(
      COUNTIF(days_since_created_profile = 6 AND udf_active_n_weeks_ago(days_seen_bits, 0)) AS active_in_week_0,
      SUM(IF(days_since_created_profile = 6, udf_bitcount_lowest_7(days_seen_bits), 0)) AS active_days_in_week_0
    ) AS metrics_1_week_post_new_profile,
    STRUCT(
      COUNTIF(days_since_created_profile = 13 AND udf_active_n_weeks_ago(days_seen_bits, 0)) AS active_in_week_1,
      COUNTIF(days_since_created_profile = 13 AND udf_active_n_weeks_ago(days_seen_bits, 1) AND udf_active_n_weeks_ago(days_seen_bits, 0)) AS active_in_weeks_0_and_1
    ) AS metrics_2_week_post_new_profile),
  STRUCT('Firefox Desktop Visited 5 URI' AS usage,
    STRUCT(
      COUNTIF(days_since_visited_5_uri < 1) AS dau,
      COUNTIF(days_since_visited_5_uri < 7) AS wau,
      COUNTIF(days_since_visited_5_uri < 28) AS mau,
      SUM(udf_bitcount_lowest_7(days_visited_5_uri_bits)) AS active_days_in_week
    ) AS metrics_daily,
    STRUCT(
      COUNTIF(days_since_created_profile = 6 AND udf_active_n_weeks_ago(days_visited_5_uri_bits, 0)) AS active_in_week_0,
      SUM(IF(days_since_created_profile = 6, udf_bitcount_lowest_7(days_visited_5_uri_bits), 0)) AS active_days_in_week_0
    ) AS metrics_1_week_post_new_profile,
    STRUCT(
      COUNTIF(days_since_created_profile = 13 AND udf_active_n_weeks_ago(days_visited_5_uri_bits, 0)) AS active_in_week_1,
      COUNTIF(days_since_created_profile = 13 AND udf_active_n_weeks_ago(days_visited_5_uri_bits, 1) AND udf_active_n_weeks_ago(days_visited_5_uri_bits, 0)) AS active_in_weeks_0_and_1
    ) AS metrics_2_week_post_new_profile),
  STRUCT('Firefox Desktop Opened Dev Tools' AS usage,
    STRUCT(
      COUNTIF(days_since_opened_dev_tools < 1) AS dau,
      COUNTIF(days_since_opened_dev_tools < 7) AS wau,
      COUNTIF(days_since_opened_dev_tools < 28) AS mau,
      SUM(udf_bitcount_lowest_7(days_opened_dev_tools_bits)) AS active_days_in_week
    ) AS metrics_daily,
    STRUCT(
      COUNTIF(days_since_created_profile = 6 AND udf_active_n_weeks_ago(days_opened_dev_tools_bits, 0)) AS active_in_week_0,
      SUM(IF(days_since_created_profile = 6, udf_bitcount_lowest_7(days_opened_dev_tools_bits), 0)) AS active_days_in_week_0
    ) AS metrics_1_week_post_new_profile,
    STRUCT(
      COUNTIF(days_since_created_profile = 13 AND udf_active_n_weeks_ago(days_opened_dev_tools_bits, 0)) AS active_in_week_1,
      COUNTIF(days_since_created_profile = 13 AND udf_active_n_weeks_ago(days_opened_dev_tools_bits, 1) AND udf_active_n_weeks_ago(days_opened_dev_tools_bits, 0)) AS active_in_weeks_0_and_1
    ) AS metrics_2_week_post_new_profile),
  STRUCT('New Firefox Desktop Profile Created' AS usage,
    STRUCT(
      COUNTIF(days_since_created_profile < 1) AS dau,
      NULL AS wau,
      NULL AS mau,
      NULL AS active_days_in_week
    ) AS metrics_daily,
    STRUCT(
      NULL AS active_in_week_0,
      NULL AS active_days_in_week_0
    ) AS metrics_1_week_post_new_profile,
    STRUCT(
      NULL AS active_in_week_1,
      NULL AS active_in_weeks_0_and_1
    ) AS metrics_2_week_post_new_profile)
  ] AS metrics,
  -- We hash client_ids into 20 buckets to aid in computing
  -- confidence intervals for mau/wau/dau sums; the particular hash
  -- function and number of buckets is subject to change in the future.
  MOD(ABS(FARM_FINGERPRINT(client_id)), 20) AS id_bucket,
  app_name,
  app_version,
  country,
  os,
  channel
FROM
  base
WHERE
  client_id IS NOT NULL
  -- Reprocess all dates by running this query with --parameter=submission_date:DATE:NULL
  AND (@submission_date IS NULL OR @submission_date = submission_date)
GROUP BY
  submission_date,
  id_bucket,
  app_name,
  app_version,
  country,
  os,
  channel
