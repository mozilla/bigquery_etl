CREATE OR REPLACE VIEW
  `moz-fx-data-shared-prod.search.mobile_search_clients_daily`
AS
SELECT
  * EXCEPT (normalized_engine),
  udf.normalize_search_engine(engine) AS normalized_engine,
FROM
  `moz-fx-data-shared-prod.search_derived.mobile_search_clients_daily_v1`
