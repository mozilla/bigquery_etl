/*
Given a map of representing activity for STRING `key`s, this
function returns an array of which `key`s were active for the
time period in question

Begin and end are both inclusive.
*/
CREATE OR REPLACE FUNCTION udf.active_values_from_map(
  days_seen_bits_map ARRAY<STRUCT<key STRING, value INT64>>,
  start_offset INT64,
  n_bits INT64
) AS (
  ARRAY(
    SELECT
      DISTINCT key
    FROM
      UNNEST(days_seen_bits_map)
    WHERE
        -- TODO: Use udf.bits28_active_in_range when it's available
      BIT_COUNT(value << (64 + start_offset - 1) >> (64 - n_bits)) > 0
  )
);

-- Tests
SELECT
  assert_array_equals(
    ['a', 'b'],
    udf.active_values_from_map(
      [STRUCT('a' AS key, 1 AS value), STRUCT('b' AS key, 3 AS value)],
      0,
      1
    )
  ),
  assert_array_equals(
    ['a'],
    udf.active_values_from_map(
      [STRUCT('a' AS key, 2048 AS value), STRUCT('b' AS key, 3 AS value)],
      -14,
      7
    )
  ),
  assert_array_equals(
    ['b'],
    udf.active_values_from_map(
      [STRUCT('a' AS key, 2048 AS value), STRUCT('b' AS key, 3 AS value)],
      -6,
      7
    )
  ),
  assert_array_equals(
    ['a', 'b'],
    udf.active_values_from_map(
      [STRUCT('a' AS key, 1 AS value), STRUCT('b' AS key, 3 AS value)],
      -27,
      28
    )
  );
