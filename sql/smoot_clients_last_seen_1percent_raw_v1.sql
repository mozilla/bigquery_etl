CREATE TEMP FUNCTION bitmask_lowest_28() AS (0x0FFFFFFF);
CREATE TEMP FUNCTION shift_one_day(x INT64) AS (IFNULL((x << 1) & bitmask_lowest_28(), 0));
CREATE TEMP FUNCTION combine_days(prev INT64, curr INT64) AS (IFNULL(shift_one_day(prev), 0) + IFNULL(curr, 0));

WITH
  _current AS (
  SELECT
    * EXCEPT (submission_date_s3),
    CAST(TRUE AS INT64) AS days_seen_bits,
    -- For measuring Active MAU, where this is the days since this
    -- client_id was an Active User as defined by
    -- https://docs.telemetry.mozilla.org/cookbooks/active_dau.html
    CAST(scalar_parent_browser_engagement_total_uri_count_sum >= 5 AS INT64) AS days_visited_5_uri_bits,
    CAST(devtools_toolbox_opened_count_sum > 0 AS INT64) AS days_opened_dev_tools_bits,
    DATE_DIFF(submission_date_s3, SAFE_CAST(SUBSTR(profile_creation_date, 0, 10) AS DATE), DAY) AS days_since_created_profile
  FROM
    telemetry.smoot_clients_daily_1percent_v1
  WHERE
    submission_date_s3 = @submission_date ),
  --
  _previous AS (
  SELECT
    * EXCEPT (submission_date, generated_time)
    REPLACE (IF(days_since_created_profile BETWEEN 0 AND 26, days_since_created_profile, NULL) AS days_since_created_profile)
  FROM
    telemetry.smoot_clients_last_seen_1percent_raw_v1 AS cls
  WHERE
    submission_date = DATE_SUB(@submission_date, INTERVAL 1 DAY)
    AND shift_one_day(days_seen_bits) > 0),
  --
  _joined AS (
  SELECT
    @submission_date AS submission_date,
    IF(_current.client_id IS NOT NULL,
      _current,
      _previous).* REPLACE (
        combine_days(_previous.days_seen_bits, _current.days_seen_bits) AS days_seen_bits,
        combine_days(_previous.days_visited_5_uri_bits, _current.days_visited_5_uri_bits) AS days_visited_5_uri_bits,
        combine_days(_previous.days_opened_dev_tools_bits, _current.days_opened_dev_tools_bits) AS days_opened_dev_tools_bits,
        -- We want to base new profile creation date on the first profile_creation_date
        -- value we observe, so we propagate a non-null previous value in preference
        -- to a non-null value on today's observation.
        COALESCE(_previous.days_since_created_profile + 1,
          _current.days_since_created_profile) AS days_since_created_profile)
  FROM
    _current
  FULL JOIN
    _previous
  USING
    -- Include sample_id to match the clustering of the tables, which may improve
    -- join performance.
    (sample_id, client_id))
  --
SELECT
  * REPLACE (
    -- Null out any fields that may contain data leaked from beyond our 28 day window.
    IF(days_since_created_profile BETWEEN 0 AND 27, days_since_created_profile, NULL) AS days_since_created_profile)
FROM
  _joined
