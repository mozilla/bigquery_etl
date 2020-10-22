SELECT
  date,
  deviceCategory,
  operatingSystem,
  browser,
  LANGUAGE AS language,
  country,
  standardized_country_list.standardized_country AS standardized_country_name,
  source,
  medium,
  campaign,
  content,
  blog,
  subblog,
  SUM(sessions) AS sessions,
  SUM(downloads) AS downloads,
  SUM(socialShare) AS socialShare,
  SUM(newsletterSubscription) AS newsletterSubscription
FROM
  `moz-fx-data-marketing-prod.ga_derived.blogs_sessions_v1` AS sessions_table
LEFT JOIN
  `moz-fx-data-marketing-prod.ga_derived.blogs_goals_v1`
USING
  (date, visitIdentifier)
LEFT JOIN
  `moz-fx-data-marketing-prod.static.standardized_country_list` AS standardized_country_list
ON
  sessions_table.country = standardized_country_list.raw_country
WHERE
  date = @submission_date
GROUP BY
  date,
  deviceCategory,
  operatingSystem,
  browser,
  LANGUAGE,
  country,
  standardized_country_name,
  source,
  medium,
  campaign,
  content,
  blog,
  subblog