CREATE TEMP FUNCTION assert_sql_equals(
  expected ANY TYPE,
  actual ANY TYPE
) AS (
  IF(
    LOWER(REGEXP_REPLACE(expected, '\\s*', '')) = LOWER(REGEXP_REPLACE(actual, '\\s*', '')),
    TRUE,
    ERROR(
      CONCAT(
        'Expected ',
        expected,
        ' but got ',
        actual
      )
    )
  )
);

-- Tests
SELECT
  assert_sql_equals("SELECT * FROM a", "SELECT\n\t*\nFROM\n\ta"),
