import os
import pytest
from pathlib import Path
from bigquery_etl.dryrun import DryRun, Errors

SQL_DIR = Path(__file__).parent.parent / "sql"


class TestDryRun:
    def test_dry_run_sql_file(self, tmp_path):
        query_file = tmp_path / "query.sql"
        query_file.write_text("SELECT 123")

        dryrun = DryRun(str(query_file))
        response = dryrun.dry_run_result
        assert response["valid"]

    def test_dry_run_invalid_sql_file(self, tmp_path):
        query_file = tmp_path / "query.sql"
        query_file.write_text("SELECT INVALID 123")

        dryrun = DryRun(str(query_file))
        response = dryrun.dry_run_result
        assert response["valid"] is False

    def test_sql_file_valid(self, tmp_path):
        query_file = tmp_path / "query.sql"
        query_file.write_text("SELECT 123")

        dryrun = DryRun(str(query_file))
        assert dryrun.is_valid()

    def test_view_file_valid(self, tmp_path):
        view_file = tmp_path / "view.sql"
        view_file.write_text(
            """
            SELECT
            *
            FROM
            `moz-fx-data-shared-prod.telemetry_derived.clients_daily_v6`
        """
        )

        # this view file is only valid with strip_dml flag
        dryrun = DryRun(sqlfile=str(view_file), strip_dml=True)
        assert dryrun.get_error() is Errors.DATE_FILTER_NEEDED
        assert dryrun.is_valid()

    def test_sql_file_invalid(self, tmp_path):
        query_file = tmp_path / "query.sql"
        query_file.write_text("SELECT INVALID 123")

        dryrun = DryRun(str(query_file))
        assert dryrun.is_valid() is False

    def test_get_referenced_tables_empty(self, tmp_path):
        query_file = tmp_path / "query.sql"
        query_file.write_text("SELECT 123")

        dryrun = DryRun(str(query_file))
        assert dryrun.get_referenced_tables() == []

    def test_get_sql(self, tmp_path):
        os.makedirs(tmp_path / "telmetry_derived")
        query_file = tmp_path / "telmetry_derived" / "query.sql"

        sql_content = "SELECT 123 "
        query_file.write_text(sql_content)

        assert DryRun(sqlfile=str(query_file)).get_sql() == sql_content
        with pytest.raises(ValueError):
            DryRun(sqlfile="invalid path").get_sql()

    def test_get_referenced_tables(self, tmp_path):
        os.makedirs(tmp_path / "telmetry_derived")
        query_file = tmp_path / "telmetry_derived" / "query.sql"
        query_file.write_text(
            "SELECT * FROM telemetry_derived.clients_daily_v6 "
            "WHERE submission_date = '2020-01-01'"
        )
        view_file = tmp_path / "telmetry_derived" / "view.sql"
        view_file.write_text(
            """
            CREATE OR REPLACE VIEW
            `moz-fx-data-shared-prod.telemetry.clients_daily`
            AS
            SELECT
            *
            FROM
            `moz-fx-data-shared-prod.telemetry_derived.clients_daily_v6`
        """
        )
        query_dryrun = DryRun(str(query_file)).get_referenced_tables()
        view_dryrun = DryRun(str(view_file), strip_dml=True).get_referenced_tables()

        assert len(query_dryrun) == 1
        assert query_dryrun[0]["datasetId"] == "telemetry_derived"
        assert query_dryrun[0]["tableId"] == "clients_daily_v6"
        assert len(view_dryrun) == 1
        assert view_dryrun[0]["datasetId"] == "telemetry_derived"
        assert view_dryrun[0]["tableId"] == "clients_daily_v6"

    def test_get_error(self, tmp_path):
        os.makedirs(tmp_path / "telemetry")
        view_file = tmp_path / "telemetry" / "view.sql"

        view_file.write_text(
            """
        CREATE OR REPLACE VIEW
          `moz-fx-data-shared-prod.telemetry.clients_daily`
        AS
        SELECT
        *
        FROM
          `moz-fx-data-shared-prod.telemetry_derived.clients_daily_v6`
        """
        )

        valid_dml_stripped = """
        SELECT
        *
        FROM
          `moz-fx-data-shared-prod.telemetry_derived.clients_daily_v6`
        WHERE submission_date > current_date()
        """

        invalid_dml_stripped = """
        SELECT
        *
        FROM
          `moz-fx-data-shared-prod.telemetry_derived.clients_daily_v6`
        WHERE something
        WHERE submission_date > current_date()
        """
        print(
            DryRun(
                sqlfile=str(view_file), content=valid_dml_stripped, strip_dml=True
            ).get_referenced_tables()
        )

        assert DryRun(sqlfile=str(view_file)).get_error() is Errors.READ_ONLY
        assert (
            DryRun(sqlfile=str(view_file), strip_dml=True).get_error()
            is Errors.DATE_FILTER_NEEDED
        )
        assert (
            DryRun(sqlfile=str(view_file), content=invalid_dml_stripped).get_error()
            is Errors.DATE_FILTER_NEEDED_AND_SYNTAX
        )
        assert (
            DryRun(
                sqlfile=str(view_file), content=valid_dml_stripped, strip_dml=True
            ).get_error()
            is None
        )
