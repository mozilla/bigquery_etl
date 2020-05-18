/*
*/
CREATE OR REPLACE FUNCTION udf.histogram_merge(
  histogram_list ANY TYPE
) AS (
  STRUCT(
    udf.mode_last(ARRAY(SELECT bucket_count FROM UNNEST(histogram_list))) AS bucket_count,
    (SELECT SUM(`sum`) FROM UNNEST(histogram_list)) AS `sum`,
    udf.mode_last(ARRAY(SELECT histogram_type FROM UNNEST(histogram_list))) AS histogram_type,
    [
      udf.mode_last(ARRAY(SELECT `range`[SAFE_OFFSET(0)] FROM UNNEST(histogram_list))),
      udf.mode_last(ARRAY(SELECT `range`[SAFE_OFFSET(1)] FROM UNNEST(histogram_list)))
    ] AS `range`,
    ARRAY(
      SELECT AS STRUCT
        key,
        SUM(value) AS value
      FROM
        UNNEST(histogram_list) AS histogram,
        UNNEST(values)
      GROUP BY
        key
    ) AS values
  )
);

-- Test
WITH histograms AS (
  SELECT
    STRUCT(
      5 AS bucket_count,
      20 AS `sum`,
      1 AS histogram_type,
      [0, 100] AS `range`,
      [STRUCT(0 AS key, 0 AS value), STRUCT(20 AS key, 1 AS value)] AS values
    ) AS h,
  UNION ALL
  SELECT
    STRUCT(
      5 AS bucket_count,
      40 AS `sum`,
      1 AS histogram_type,
      [0, 100] AS `range`,
      [STRUCT(0 AS key, 0 AS value), STRUCT(40 AS key, 1 AS value)] AS values
    )
),
merged AS (
  SELECT
    udf.histogram_merge(ARRAY_AGG(h)) AS h
  FROM
    histograms
)
SELECT
  assert_histogram_equals(
    STRUCT(
      5 AS bucket_count,
      60  AS `sum`,
      1 AS histogram_type,
      [0, 100] AS `range`,
      [STRUCT(0 AS key, 0 AS value), STRUCT(20, 1), STRUCT(40, 1)] AS values
    ),
    h
  )
FROM
  merged;
