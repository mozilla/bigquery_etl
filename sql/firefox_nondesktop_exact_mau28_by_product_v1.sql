SELECT
  submission_date,
  product,
  SUM(mau) AS mau,
  SUM(wau) AS wau,
  SUM(dau) AS dau,
  SUM(IF(country IN ('US', 'FR', 'DE', 'UK', 'CA'), mau, 0)) AS tier1_mau,
  SUM(IF(country IN ('US', 'FR', 'DE', 'UK', 'CA'), wau, 0)) AS tier1_wau,
  SUM(IF(country IN ('US', 'FR', 'DE', 'UK', 'CA'), dau, 0)) AS tier1_dau
FROM
  `moz-fx-data-derived-datasets.analysis.firefox_nondesktop_exact_mau28_by_dimensions_v1`
GROUP BY
  submission_date,
  product

-- This is a "live view" and can be updated via bq:
-- bq mk --project moz-fx-data-derived-datasets --use_legacy_sql=false --view "$(cat sql/firefox_nondesktop_exact_mau28_by_product_v1.sql)" analysis.firefox_nondesktop_exact_mau28_by_product_v1
