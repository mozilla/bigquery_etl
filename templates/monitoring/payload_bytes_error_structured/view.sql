CREATE OR REPLACE VIEW
  `moz-fx-data-shared-prod.monitoring.payload_bytes_error_structured`
AS SELECT
  * EXCEPT (remote_addr, x_forwarded_for)
FROM
  `moz-fx-data-shared-prod.payload_bytes_error.structured`
