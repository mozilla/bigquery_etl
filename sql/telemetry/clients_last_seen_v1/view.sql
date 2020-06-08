CREATE OR REPLACE VIEW
  `moz-fx-data-shared-prod.telemetry.clients_last_seen_v1`
AS
SELECT
  -- We cannot use UDFs in a view, so we paste the body of udf.bitpos(bits) literally here.
  CAST(SAFE.LOG(days_seen_bits & -days_seen_bits, 2) AS INT64) AS days_since_seen,
  CAST(
    SAFE.LOG(days_visited_5_uri_bits & -days_visited_5_uri_bits, 2) AS INT64
  ) AS days_since_visited_5_uri,
  CAST(
    SAFE.LOG(days_opened_dev_tools_bits & -days_opened_dev_tools_bits, 2) AS INT64
  ) AS days_since_opened_dev_tools,
  CAST(
    SAFE.LOG(days_created_profile_bits & -days_created_profile_bits, 2) AS INT64
  ) AS days_since_created_profile,
  -- Segment definitions; see https://docs.telemetry.mozilla.org/concepts/segments.html
  -- 0x0FFFFFFE is a bitmask that accepts the previous 27 days, excluding the current day (rightmost bit)
  -- 0x183060C183 == 0b000001100000110000011000001100000110000011 is a bit mask that accepts a pair of
  -- consecutive days each week for six weeks; the current day and previous day are accepted.
  BIT_COUNT(days_seen_bits & 0x0FFFFFFE) >= 14 AS is_regular_user_v3,
  days_seen_bits & 0x0FFFFFFE = 0 AS is_new_or_resurrected_v3,
  BIT_COUNT(days_seen_bits & 0x0FFFFFFE) >= 14
  AND (
    (
      BIT_COUNT(
        cls.days_seen_bits & 0x0FFFFFFE & (
          0x183060C183 >> (8 - EXTRACT(DAYOFWEEK FROM cls.submission_date))
        )
      ) <= 1
    )
    OR (
      BIT_COUNT(
        cls.days_seen_bits & 0x0FFFFFFE & (
          0x183060C183 >> (8 - EXTRACT(DAYOFWEEK FROM cls.submission_date) - 1)
        )
      ) <= 1
    )
    OR (
      BIT_COUNT(
        cls.days_seen_bits & 0x0FFFFFFE & (
          0x183060C183 >> (8 - EXTRACT(DAYOFWEEK FROM cls.submission_date) + 1)
        )
      ) <= 1
    )
  ) AS is_weekday_regular_v1,
  BIT_COUNT(days_seen_bits & 0x0FFFFFFE) >= 14
  AND NOT (
    (
      BIT_COUNT(
        cls.days_seen_bits & 0x0FFFFFFE & (
          0x183060C183 >> (8 - EXTRACT(DAYOFWEEK FROM cls.submission_date))
        )
      ) <= 1
    )
    OR (
      BIT_COUNT(
        cls.days_seen_bits & 0x0FFFFFFE & (
          0x183060C183 >> (8 - EXTRACT(DAYOFWEEK FROM cls.submission_date) - 1)
        )
      ) <= 1
    )
    OR (
      BIT_COUNT(
        cls.days_seen_bits & 0x0FFFFFFE & (
          0x183060C183 >> (8 - EXTRACT(DAYOFWEEK FROM cls.submission_date) + 1)
        )
      ) <= 1
    )
  ) AS is_allweek_regular_v1,
  * EXCEPT (
    active_experiment_id,
    scalar_parent_dom_contentprocess_troubled_due_to_memory_sum,
    total_hours_sum,
    histogram_parent_devtools_developertoolbar_opened_count_sum,
    active_experiment_branch
  ) REPLACE(
    IFNULL(country, '??') AS country,
    IFNULL(city, '??') AS city,
    IFNULL(geo_subdivision1, '??') AS geo_subdivision1,
    IFNULL(geo_subdivision2, '??') AS geo_subdivision2,
    ARRAY(
      SELECT AS STRUCT
        *,
        CAST(SAFE.LOG(bits & -bits, 2) AS INT64) AS days_since_seen
      FROM
        UNNEST(days_seen_in_experiment)
    ) AS days_seen_in_experiment
  ),
  -- TODO: Announce and remove this temporary field.
  CAST(sample_id AS STRING) AS _sample_id_string
FROM
  `moz-fx-data-shared-prod.telemetry_derived.clients_last_seen_v1`
