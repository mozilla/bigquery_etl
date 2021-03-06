WITH combined AS (
  SELECT
    context_id,
    DATE(submission_timestamp) AS submission_date,
    'suggest' AS source,
    'impression' AS event_type,
    normalized_country_code AS country,
    metadata.geo.subdivision1 AS subdivision1,
    advertiser,
    release_channel,
    position,
  FROM
    contextual_services_stable.quicksuggest_impression_v1
  UNION ALL
  SELECT
    context_id,
    DATE(submission_timestamp) AS submission_date,
    'suggest' AS source,
    'click' AS event_type,
    normalized_country_code AS country,
    metadata.geo.subdivision1 AS subdivision1,
    advertiser,
    release_channel,
    position,
  FROM
    contextual_services_stable.quicksuggest_click_v1
  UNION ALL
  SELECT
    context_id,
    DATE(submission_timestamp) AS submission_date,
    'topsites' AS source,
    'impression' AS event_type,
    normalized_country_code AS country,
    metadata.geo.subdivision1 AS subdivision1,
    advertiser,
    release_channel,
    position,
  FROM
    contextual_services_stable.topsites_impression_v1
  UNION ALL
  SELECT
    context_id,
    DATE(submission_timestamp) AS submission_date,
    'topsites' AS source,
    'click' AS event_type,
    normalized_country_code AS country,
    metadata.geo.subdivision1 AS subdivision1,
    advertiser,
    release_channel,
    position,
  FROM
    contextual_services_stable.topsites_click_v1
),
with_event_count AS (
  SELECT
    *,
    COUNT(*) OVER (
      PARTITION BY
        submission_date,
        context_id,
        source,
        event_type
    ) AS user_event_count,
  FROM
    combined
  ORDER BY
    context_id
)
SELECT
  * EXCEPT (context_id, user_event_count),
  COUNT(*) AS event_count,
  COUNT(DISTINCT(context_id)) AS user_count,
FROM
  with_event_count
WHERE
  submission_date = @submission_date
  AND NOT (user_event_count > 50 AND event_type = 'click')
GROUP BY
  submission_date,
  source,
  event_type,
  country,
  subdivision1,
  advertiser,
  release_channel,
  position
