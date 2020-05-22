{{ header }}
{% include "scalar_bucket_counts_v1.udf.sql" %}
{% from 'macros.sql' import enumerate_table_combinations %}

WITH
bucketed_booleans AS (
  SELECT
    client_id,
    {{ attributes }},
    udf_boolean_buckets(scalar_aggregates) AS scalar_aggregates
  FROM
    {{ source_table }}
),
bucketed_scalars AS (
  SELECT
    client_id,
    {{ attributes }},
    {{ aggregate_attributes }},
    agg_type,
    SAFE_CAST(udf_bucket(SAFE_CAST(value AS FLOAT64)) AS STRING) AS bucket
  FROM
    {{ source_table }}
  CROSS JOIN
    UNNEST(scalar_aggregates)
  WHERE
    metric_type in ({{ scalar_metric_types }})
),
booleans_and_scalars AS (
  SELECT
    * EXCEPT (scalar_aggregates)
  FROM
    bucketed_booleans
  CROSS JOIN
    UNNEST(scalar_aggregates)
  UNION ALL
  SELECT
    *
  FROM
    bucketed_scalars
),
{{
    enumerate_table_combinations(
        "booleans_and_scalars",
        "all_combos",
        cubed_attributes,
        attribute_combinations
    )
}}
SELECT
  {{ attributes }},
  {{ aggregate_attributes }},
  agg_type AS client_agg_type,
  'histogram' AS agg_type,
  bucket,
  COUNT(*) AS count
FROM
  all_combos
GROUP BY
  {{ attributes }},
  {{ aggregate_attributes }},
  client_agg_type,
  bucket
