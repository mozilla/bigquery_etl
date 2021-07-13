CREATE TEMP FUNCTION in_available_geos(`date` DATE, country STRING) AS (
  country IN ("United States", "United Kingdom", "Canada", "Malaysia", "Singapore", "New Zealand")
  OR (`date` >= "2021-04-28" AND country IN ("France", "Germany"))
  OR (`date` >= "2021-07-12" AND country IN ("Austria", "Belgium", "Spain", "Italy", "Switzerland"))
);

WITH website_base AS (
  SELECT
    `date`,
    mozfun.norm.vpn_attribution(
      NULL, -- provider
      NULL, -- referrer
      campaign,
      content,
      medium,
      source
    ).*,
    sessions,
    subscribe_intent_goal,
    country,
  FROM
    site_metrics_summary_v1
  WHERE
    -- Populate from mozilla.org starting 2021-03-11, and from vpn.mozilla.org before that
    IF(`date` < DATE "2021-03-11", site = "vpn.mozilla.org", site = "mozilla.org")
),
website AS (
  SELECT
    `date`,
    IF(
      COUNT(DISTINCT normalized_acquisition_channel) = 1,
      ANY_VALUE(normalized_acquisition_channel),
      ERROR("normalized_acquisition_channel must have one value per group")
    ) AS normalized_acquisition_channel,
    normalized_medium,
    normalized_source,
    normalized_campaign,
    normalized_content,
    IF(
      COUNT(DISTINCT website_channel_group) = 1,
      ANY_VALUE(website_channel_group),
      ERROR("website_channel_group must have one value per group")
    ) AS website_channel_group,
    SUM(sessions) AS sessions,
    SUM(IF(in_available_geos(`date`, country), sessions, 0)) AS sessions_in_available_geos,
    SUM(subscribe_intent_goal) AS subscribe_intent,
    SUM(
      IF(in_available_geos(`date`, country), subscribe_intent_goal, 0)
    ) AS subscription_intent_in_available_geos
  FROM
    website_base
  WHERE
    `date` = @date
  GROUP BY
    `date`,
    normalized_medium,
    normalized_source,
    normalized_campaign,
    normalized_content
),
subscriptions AS (
  SELECT
    DATE(subscription_start_date) AS `date`,
    IF(
      COUNT(DISTINCT normalized_acquisition_channel) = 1,
      ANY_VALUE(normalized_acquisition_channel),
      ERROR("normalized_acquisition_channel must have one value per group")
    ) AS normalized_acquisition_channel,
    normalized_medium,
    normalized_source,
    normalized_campaign,
    normalized_content,
    IF(
      COUNT(DISTINCT website_channel_group) = 1,
      ANY_VALUE(website_channel_group),
      ERROR("website_channel_group must have one value per group")
    ) AS website_channel_group,
    COUNT(DISTINCT subscription_id) AS total_new_subscriptions,
    COUNT(
      DISTINCT IF(DATE(customer_start_date) < DATE(subscription_start_date), subscription_id, NULL)
    ) AS returning_subscriptions,
  FROM
    all_subscriptions_v1
  WHERE
    DATE(subscription_start_date) = @date
    AND product_name = "Mozilla VPN"
    AND provider LIKE "FxA %"
    AND normalized_acquisition_channel LIKE "Website%"
  GROUP BY
    `date`,
    normalized_medium,
    normalized_source,
    normalized_campaign,
    normalized_content
)
SELECT
  `date`,
  IF(
    -- TODO why is subscriptions.date not checked?
    website.date IS NOT NULL,
    "Successfully Joined",
    "Join Unsuccessful"
  ) AS utm_join,
  -- Populated from mozilla.org starting 2021-03-11, and from vpn.mozilla.org before that
  IF(`date` < DATE "2021-03-11", "vpn.mozilla.org", "mozilla.org") AS site,
  COALESCE(
    subscriptions.normalized_acquisition_channel,
    website.normalized_acquisition_channel
  ) AS normalized_acquisition_channel,
  normalized_medium,
  normalized_source,
  normalized_campaign,
  normalized_content,
  COALESCE(
    subscriptions.website_channel_group,
    website.website_channel_group
  ) AS website_channel_group,
  -- from website
  sessions,
  sessions_in_available_geos,
  subscribe_intent,
  subscription_intent_in_available_geos,
  -- from subscriptions
  total_new_subscriptions,
  returning_subscriptions,
  (total_new_subscriptions - returning_subscriptions) AS first_time_subscriptions,
FROM
  website
FULL JOIN
  subscriptions
USING
  (`date`, normalized_medium, normalized_source, normalized_campaign, normalized_content)
