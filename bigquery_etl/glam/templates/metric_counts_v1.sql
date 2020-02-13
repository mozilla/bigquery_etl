{{ header }}
{% include "metric_counts_v1.udf.scalar.sql" %}

{% for grouping_attributes, hidden_attributes in attribute_combinations %}
    SELECT
        {% if grouping_attributes %}
            {{ grouping_attributes | join(",") }},
        {% endif %}
        {% for hidden in hidden_attributes %}
            CAST(NULL AS STRING) AS {{ hidden }},
        {% endfor %}
        {{ aggregate_attributes }},
        client_agg_type,
        agg_type,
        SUM(count) AS total_users,
        CASE
        WHEN
            metric_type = 'scalar'
            OR metric_type = 'keyed-scalar'
        THEN
            udf_fill_buckets(
                udf_dedupe_map_sum(ARRAY_AGG(STRUCT<key STRING, value FLOAT64>(bucket, count))),
                udf_get_buckets()
            )
        WHEN
            metric_type = 'boolean'
            OR metric_type = 'keyed-scalar-boolean'
        THEN
            udf_fill_buckets(
                udf_dedupe_map_sum(ARRAY_AGG(STRUCT<key STRING, value FLOAT64>(bucket, count))),
                ['always', 'never', 'sometimes']
            )
        END
        AS aggregates
    FROM
        {{ source_table }}
    WHERE
        first_bucket IS NOT NULL
        {% if "os" in grouping_attributes %}
            AND os IS NOT NULL
        {% endif %}
    GROUP BY
        {% if grouping_attributes %}
            {{ grouping_attributes | join(",") }},
        {% endif %}
        {{ aggregate_attributes }},
        {{ aggregate_grouping }}
    {% if not loop.last %}
        UNION ALL
    {% endif %}
{% endfor %}
