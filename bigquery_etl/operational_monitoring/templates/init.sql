CREATE TABLE IF NOT EXISTS
  `{{gcp_project}}.{{dataset}}.{{slug}}` (
    submission_date DATE,
    client_id STRING,
    build_id STRING,
    branch STRING,
    {% for dimension in dimensions %}
      {{ dimension.name }} STRING,
    {% endfor %}
    metrics ARRAY<
      STRUCT<
        name STRING,
        histograms ARRAY<
          STRUCT<
            bucket_count INT64,
            sum INT64,
            histogram_type INT64,
            `range` ARRAY<INT64>,
            VALUES
              ARRAY<STRUCT<key INT64, value INT64>>
          >
        >
      >
    >)
PARTITION BY submission_date
CLUSTER BY
    build_id
OPTIONS (
    require_partition_filter = TRUE,
    partition_expiration_days = 7
)
