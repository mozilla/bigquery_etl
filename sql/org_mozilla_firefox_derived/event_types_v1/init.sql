CREATE OR REPLACE TABLE
  org_mozilla_firefox_derived.event_types_v1 AS
WITH
  sample AS (
  SELECT
    name AS event,
    * EXCEPT (name)
  FROM
    org_mozilla_firefox.events
  CROSS JOIN
    UNNEST(events) AS event
  WHERE
    DATE(submission_timestamp) >= '2020-01-01'
  ),
  primary_event_types AS (
  SELECT
    category,
    event,
    MIN(timestamp) AS first_timestamp,
    ROW_NUMBER() OVER (ORDER BY MIN(timestamp) ASC, category ASC, event ASC) AS primary_index,
  FROM
    sample
  GROUP BY
    category,
    event),
  event_property_indices AS (
  SELECT
    category,
    event,
    MIN(timestamp) AS first_timestamp,
    event_property.key AS event_property,
    ROW_NUMBER() OVER (PARTITION BY category, event ORDER BY MIN(timestamp) ASC) AS event_property_index,
  FROM
    sample,
    UNNEST(extra) AS event_property
  GROUP BY
    category,
    event,
    event_property),
  event_property_value_indices AS (
  SELECT
    category,
    event,
    MIN(timestamp) AS first_timestamp,
    event_property.key AS event_property,
    event_property.value AS event_property_value,
    ROW_NUMBER() OVER (PARTITION BY category, event, event_property.key ORDER BY MIN(timestamp) ASC) AS event_property_value_index,
  FROM
    sample,
    UNNEST(extra) AS event_property
  GROUP BY
    category,
    event,
    event_property,
    event_property_value
  ), per_event_property AS (
  SELECT
    category,
    event,
    event_property,
    event_property_index,
    ARRAY_AGG(STRUCT(event_property_value AS key, udf.event_code_points_to_string([event_property_value_index]) AS value, event_property_value_index AS index) ORDER BY event_property_value_index ASC) AS values,
  FROM
    event_property_value_indices
  INNER JOIN
    event_property_indices
    USING (category, event, event_property)
  GROUP BY
    category,
    event,
    event_property,
    event_property_index
  ),
  per_event AS (
  SELECT
    category,
    event,
    first_timestamp,
    primary_index AS numeric_index,
    udf.event_code_points_to_string([primary_index]) AS index,
    ARRAY_AGG(STRUCT(event_property AS key, values AS value, event_property_index AS index) ORDER BY event_property_index ASC) AS event_properties
  FROM
    primary_event_types
  LEFT JOIN
    per_event_property
    USING (category, event)
  GROUP BY
    category,
    event,
    first_timestamp,
    primary_index
  )

SELECT *
FROM per_event
ORDER BY numeric_index ASC
