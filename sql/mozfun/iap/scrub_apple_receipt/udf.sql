CREATE OR REPLACE FUNCTION iap.scrub_apple_receipt(apple_receipt ANY TYPE)
RETURNS STRUCT<
  environment STRING,
  active_periods ARRAY<STRUCT<start_date DATE, end_date DATE, `interval` STRING>>
> AS (
  STRUCT(
    apple_receipt.environment,
    -- extract a list of start and end dates that doesn't overlap or repeat
    ARRAY(
      WITH receipts AS (
        SELECT
          TIMESTAMP_MILLIS(purchase_date_ms) AS start_time,
          TIMESTAMP_MILLIS(expires_date_ms) AS end_time,
          iap.derive_apple_subscription_interval(
            DATETIME(TIMESTAMP_MILLIS(purchase_date_ms), "America/Los_Angeles"),
            DATETIME(TIMESTAMP_MILLIS(expires_date_ms), "America/Los_Angeles")
          ) AS `interval`,
        FROM
          UNNEST(apple_receipt.receipt.in_app)
        WHERE
          is_trial_period = "false"
      ),
      exploded AS (
        SELECT DISTINCT
          date,
          IF(
            -- TRUE when date - 1 is missing
            ANY_VALUE(date) OVER (
              PARTITION BY
                `interval`
              ORDER BY
                UNIX_DATE(date)
              RANGE BETWEEN
                1 PRECEDING
                AND 1 PRECEDING
            ) IS NULL,
            date,
            NULL
          ) AS start_date,
          IF(
            -- TRUE when date + 1 is missing
            ANY_VALUE(date) OVER (
              PARTITION BY
                `interval`
              ORDER BY
                UNIX_DATE(date)
              RANGE BETWEEN
                1 FOLLOWING
                AND 1 FOLLOWING
            ) IS NULL,
            date + 1,
            NULL
          ) AS end_date,
          `interval`,
        FROM
          receipts
        CROSS JOIN
          UNNEST(
            GENERATE_DATE_ARRAY(
              DATE(start_time),
              -- don't include the last day, it will be included on the next receipt
              DATE(end_time) - 1
            )
          ) AS date
      ),
      matched AS (
        SELECT
          start_date,
          -- MIN(end_date) where end_date > start_date
          MIN(end_date) OVER (
            PARTITION BY
              `interval`
            ORDER BY
              date
            ROWS BETWEEN
              CURRENT ROW
              AND UNBOUNDED FOLLOWING
          ) AS end_date,
          `interval`,
        FROM
          exploded
      )
      SELECT AS STRUCT
        *
      FROM
        matched
      WHERE
        start_date IS NOT NULL
    ) AS active_periods
  )
);

SELECT
  assert.json_equals(
    STRUCT(
      "Production" AS environment,
      [
        STRUCT(DATE "2020-01-01" AS start_date, "2020-01-03" AS end_date, "day" AS `interval`),
        ("2020-01-04", "2020-01-05", "day"),
        ("2020-01-07", "2020-01-08", "day")
      ] AS active_periods
    ),
    iap.scrub_apple_receipt(
      STRUCT(
        "Production" AS environment,
        STRUCT(
          [
            STRUCT(
              UNIX_MILLIS(TIMESTAMP "2020-01-01") AS purchase_date_ms,
              UNIX_MILLIS(TIMESTAMP "2020-01-02") AS expires_date_ms,
              "false" AS is_trial_period
            ),
            (UNIX_MILLIS(TIMESTAMP "2020-01-02"), UNIX_MILLIS(TIMESTAMP "2020-01-03"), "false"),
            (UNIX_MILLIS(TIMESTAMP "2020-01-04"), UNIX_MILLIS(TIMESTAMP "2020-01-05"), "false"),
            (UNIX_MILLIS(TIMESTAMP "2020-01-07"), UNIX_MILLIS(TIMESTAMP "2020-01-08"), "false")
          ] AS in_app
        ) AS receipt
      )
    )
  )
