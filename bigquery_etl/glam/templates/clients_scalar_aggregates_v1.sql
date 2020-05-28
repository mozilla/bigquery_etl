{{ header }}
{% include "clients_scalar_aggregates_v1.udf.sql" %}

WITH filtered_date_channel AS (
  SELECT
    *
  FROM
    {{ source_table }}
  WHERE
    submission_date = @submission_date
),
filtered_aggregates AS (
  SELECT
    submission_date,
    {{ attributes }},
    {{ user_data_attributes }},
    agg_type,
    value
  FROM
    filtered_date_channel
  CROSS JOIN
    UNNEST(scalar_aggregates)
  WHERE
    value IS NOT NULL
),
version_filtered_new AS (
  SELECT
    submission_date,
    {% for attribute in attributes_list %}
      scalar_aggs.{{ attribute }},
    {% endfor %}
    {{ user_data_attributes }},
    agg_type,
    value
  FROM
    filtered_aggregates AS scalar_aggs
  LEFT JOIN
      glam_etl.{{ prefix }}__latest_versions_v1
  USING
      (channel)
  WHERE
      app_version >= (latest_version - 2)
),
scalar_aggregates_new AS (
  SELECT
    {{ attributes }},
    {{ user_data_attributes }},
    agg_type,
    --format:off
    CASE agg_type
      WHEN 'max' THEN max(value)
      WHEN 'min' THEN min(value)
      WHEN 'count' THEN sum(value)
      WHEN 'sum' THEN sum(value)
      WHEN 'false' THEN sum(value)
      WHEN 'true' THEN sum(value)
    END AS value
    --format:on
  FROM
    version_filtered_new
  GROUP BY
    {{ attributes }},
    {{ user_data_attributes }},
    agg_type
),
filtered_new AS (
  SELECT
    {{ attributes }},
    ARRAY_AGG(({{ user_data_attributes }}, agg_type, value)) AS scalar_aggregates
  FROM
    scalar_aggregates_new
  GROUP BY
    {{ attributes }}

),
filtered_old AS (
  SELECT
    {% for attribute in attributes_list %}
      scalar_aggs.{{ attribute }},
    {% endfor %}
    scalar_aggregates
  FROM
    {{ destination_table }} AS scalar_aggs
  LEFT JOIN
      glam_etl.{{ prefix }}__latest_versions_v1
  USING
      (channel)
  WHERE
      app_version >= (latest_version - 2)
),
joined_new_old AS (
  SELECT
    {% for attribute in attributes_list %}
      COALESCE(old_data.{{attribute}}, new_data.{{attribute}}) as {{attribute}},
    {% endfor %}
    COALESCE(old_data.scalar_aggregates, []) AS old_aggs,
    COALESCE(new_data.scalar_aggregates, []) AS new_aggs
  FROM
    filtered_new AS new_data
  FULL OUTER JOIN
    filtered_old AS old_data
  USING
    ({{ attributes }})
)
SELECT
  {{ attributes }},
  udf_merged_user_data(
    ARRAY_CONCAT(old_aggs, new_aggs)
  ) AS scalar_aggregates
FROM
  joined_new_old
