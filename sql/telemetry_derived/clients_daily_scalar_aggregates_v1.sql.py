#!/usr/bin/env python3
"""clients_daily_scalar_aggregates query generator."""
import sys
import json
import gzip
import argparse
import textwrap
import subprocess
import urllib.request
from pathlib import Path
from time import sleep

sys.path.append(str(Path(__file__).parent.parent.parent.resolve()))
from bigquery_etl.format_sql.formatter import reformat
from bigquery_etl.util.common import snake_case


PROBE_INFO_SERVICE = (
    "https://probeinfo.telemetry.mozilla.org/firefox/all/main/all_probes"
)

p = argparse.ArgumentParser()
p.add_argument(
    "--agg-type",
    type=str,
    help="One of scalars/keyed_scalars/keyed_booleans",
    required=True,
)
p.add_argument(
    "--json-output",
    action='store_true',
    help="Output the result wrapped in json parseable as an XCOM",
)
p.add_argument(
    "--wait-seconds",
    type=int,
    default=0,
    help="Add a delay before executing the script to allow time for the xcom sidecar to complete startup",
)


def generate_sql(
    agg_type,
    aggregates,
    additional_queries,
    additional_partitions,
    select_clause,
    querying_table,
    json_output,
):
    """Create a SQL query for the clients_daily_scalar_aggregates dataset."""
    query = textwrap.dedent(
        f"""-- Query generated by: sql/telemetry_derived/clients_daily_scalar_aggregates.sql.py --agg-type {agg_type}
        WITH valid_build_ids AS (
            SELECT
              DISTINCT(build.build.id) AS build_id
            FROM
              `moz-fx-data-shared-prod.telemetry.buildhub2`
        ),
        filtered AS (
            SELECT
                *,
                SPLIT(application.version, '.')[OFFSET(0)] AS app_version,
                DATE(submission_timestamp) as submission_date,
                normalized_os as os,
                application.build_id AS app_build_id,
                normalized_channel AS channel
            FROM `moz-fx-data-shared-prod.telemetry_stable.main_v4`
            INNER JOIN valid_build_ids
            ON (application.build_id = build_id)
            WHERE DATE(submission_timestamp) = @submission_date
                AND normalized_channel in (
                  "release", "beta", "nightly"
                )
                AND client_id IS NOT NULL),

        {additional_queries}

        sampled_data AS (
            SELECT *
            FROM {querying_table}
            WHERE channel IN ("nightly", "beta")
                OR (channel = "release" AND os != "Windows")
                OR (channel = "release" AND
                    os = "Windows" AND
                    MOD(sample_id, @sample_size) = 0)
        ),

        -- Using `min` for when `agg_type` is `count` returns null when all rows are null
        aggregated AS (
            SELECT
                submission_date,
                sample_id,
                client_id,
                os,
                app_version,
                app_build_id,
                channel,
                {aggregates}
            FROM sampled_data
            GROUP BY
                submission_date,
                sample_id,
                client_id,
                os,
                app_version,
                app_build_id,
                channel
                {additional_partitions})

            {select_clause}
        """
    )

    if json_output:
        return json.dumps(query)
    else:
        return query


def _get_generic_keyed_scalar_sql(probes, value_type):
    probes_struct = []
    for probe, processes in probes.items():
        for process in processes:
            probes_struct.append(
                f"('{probe}', '{process}', payload.processes.{process}.keyed_scalars.{probe})"
            )

    probes_struct.sort()
    probes_arr = ",\n\t\t\t".join(probes_struct)

    additional_queries = f"""
        grouped_metrics AS
          (SELECT
            sample_id,
            client_id,
            submission_date,
            os,
            app_version,
            app_build_id,
            channel,
            ARRAY<STRUCT<
                name STRING,
                process STRING,
                value ARRAY<STRUCT<key STRING, value {value_type}>>
            >>[
              {probes_arr}
            ] as metrics
          FROM filtered),

          flattened_metrics AS
            (SELECT
              sample_id,
              client_id,
              submission_date,
              os,
              app_version,
              app_build_id,
              channel,
              metrics.name AS metric,
              metrics.process AS process,
              value.key AS key,
              value.value AS value
            FROM grouped_metrics
            CROSS JOIN UNNEST(metrics) AS metrics,
            UNNEST(metrics.value) AS value),
    """

    querying_table = "flattened_metrics"

    additional_partitions = """,
                            metric,
                            process,
                            key
    """

    return {
        "additional_queries": additional_queries,
        "additional_partitions": additional_partitions,
        "querying_table": querying_table,
    }


def get_keyed_boolean_probes_sql_string(probes):
    """Put together the subsets of SQL required to query keyed booleans."""
    sql_strings = _get_generic_keyed_scalar_sql(probes, "BOOLEAN")
    sql_strings[
        "probes_string"
    ] = """
        metric,
        key,
        process,
        SUM(CASE WHEN value = True THEN 1 ELSE 0 END) AS true_col,
        SUM(CASE WHEN value = False THEN 1 ELSE 0 END) AS false_col
    """

    sql_strings[
        "select_clause"
    ] = """
        SELECT
              sample_id,
              client_id,
              submission_date,
              os,
              app_version,
              app_build_id,
              channel,
              ARRAY_CONCAT_AGG(ARRAY<STRUCT<
                    metric STRING,
                    metric_type STRING,
                    key STRING,
                    process STRING,
                    agg_type STRING,
                    value FLOAT64
                >>
                [
                    (metric, 'keyed-scalar-boolean', key, process, 'true', true_col),
                    (metric, 'keyed-scalar-boolean', key, process, 'false', false_col)
                ]
            ) AS scalar_aggregates
        FROM aggregated
        GROUP BY
            sample_id,
            client_id,
            submission_date,
            os,
            app_version,
            app_build_id,
            channel
    """
    return sql_strings


def get_keyed_scalar_probes_sql_string(probes):
    """Put together the subsets of SQL required to query keyed scalars."""
    sql_strings = _get_generic_keyed_scalar_sql(probes, "INT64")
    sql_strings[
        "probes_string"
    ] = """
        metric,
        process,
        key,
        MAX(value) AS max,
        MIN(value) AS min,
        AVG(value) AS avg,
        SUM(value) AS sum,
        IF(MIN(value) IS NULL, NULL, COUNT(*)) AS count
    """

    sql_strings[
        "select_clause"
    ] = """
        SELECT
            sample_id,
            client_id,
            submission_date,
            os,
            app_version,
            app_build_id,
            channel,
            ARRAY_CONCAT_AGG(ARRAY<STRUCT<
                metric STRING,
                metric_type STRING,
                key STRING,
                process STRING,
                agg_type STRING,
                value FLOAT64
            >>
                [
                    (metric, 'keyed-scalar', key, process, 'max', max),
                    (metric, 'keyed-scalar', key, process, 'min', min),
                    (metric, 'keyed-scalar', key, process, 'avg', avg),
                    (metric, 'keyed-scalar', key, process, 'sum', sum),
                    (metric, 'keyed-scalar', key, process, 'count', count)
                ]
        ) AS scalar_aggregates
        FROM aggregated
        GROUP BY
            sample_id,
            client_id,
            submission_date,
            os,
            app_version,
            app_build_id,
            channel
    """
    return sql_strings


def get_scalar_probes_sql_strings(probes, scalar_type):
    """Put together the subsets of SQL required to query scalars or booleans."""
    if scalar_type == "keyed_scalars":
        return get_keyed_scalar_probes_sql_string(probes["keyed"])

    if scalar_type == "keyed_booleans":
        return get_keyed_boolean_probes_sql_string(probes["keyed_boolean"])

    probe_structs = []
    for probe, processes in probes["scalars"].items():
        for process in processes:
            probe_structs.append((
                f"('{probe}', 'scalar', '', '{process}', 'max', "
                f"max(CAST(payload.processes.{process}.scalars.{probe} AS INT64)))")
            )
            probe_structs.append((
                f"('{probe}', 'scalar', '', '{process}', 'avg', "
                f"avg(CAST(payload.processes.{process}.scalars.{probe} AS INT64)))")
            )
            probe_structs.append((
                f"('{probe}', 'scalar', '', '{process}', 'min', "
                f"min(CAST(payload.processes.{process}.scalars.{probe} AS INT64)))")
            )
            probe_structs.append((
                f"('{probe}', 'scalar', '', '{process}', 'sum', "
                f"sum(CAST(payload.processes.{process}.scalars.{probe} AS INT64)))")
            )
            probe_structs.append(
                f"('{probe}', 'scalar', '', '{process}', 'count', IF(MIN(payload.processes.{process}.scalars.{probe}) IS NULL, NULL, COUNT(*)))"
            )

    for probe, processes in probes["booleans"].items():
        for process in processes:
            probe_structs.append(
                (
                    f"('{probe}', 'boolean', '', '{process}', 'false', "
                    f"SUM(case when payload.processes.{process}.scalars.{probe} = False "
                    "THEN 1 ELSE 0 END))"
                )
            )
            probe_structs.append(
                (
                    f"('{probe}', 'boolean', '', '{process}', 'true', "
                    f"SUM(case when payload.processes.{process}.scalars.{probe} = True "
                    "THEN 1 ELSE 0 END))"
                )
            )

    probe_structs.sort()
    probes_arr = ",\n\t\t\t".join(probe_structs)
    probes_string = f"""
            ARRAY<STRUCT<
                metric STRING,
                metric_type STRING,
                key STRING,
                process STRING,
                agg_type STRING,
                value FLOAT64
            >> [
                {probes_arr}
            ] AS scalar_aggregates
    """

    select_clause = f"""
        SELECT *
        FROM aggregated
    """

    return {"probes_string": probes_string, "select_clause": select_clause}


def save_scalars_by_type(scalars_dict, scalar, process):
    if scalars_dict is None:
        return

    processes = scalars_dict.setdefault(scalar, set())
    processes.add(process)
    scalars_dict[scalar] = processes


def filter_scalars_dict(scalars_dict, required_probes):
    return {
        scalar: process for scalar, process in scalars_dict.items() if scalar in required_probes
    }

def get_scalar_probes(scalar_type):
    """Find all scalar probes in main summary.

    Note: that non-integer scalar probes are not included.
    """
    project = "moz-fx-data-shared-prod"
    main_summary_scalars = {}
    main_summary_record_scalars = {}
    main_summary_boolean_record_scalars = {}
    main_summary_boolean_scalars = {}

    process = subprocess.Popen(
        [
            "bq",
            "show",
            "--schema",
            "--format=json",
            f"{project}:telemetry_stable.main_v4",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    stdout, stderr = process.communicate()
    if process.returncode > 0:
        raise Exception(
            f"Call to bq exited non-zero: {process.returncode}", stdout, stderr
        )
    main_summary_schema = json.loads(stdout)

    scalars_fields = []
    for field in main_summary_schema:
        if field["name"] != "payload":
            continue

        for payload_field in field["fields"]:
            if payload_field["name"] == "processes":
                for processes_field in payload_field["fields"]:
                    if processes_field["name"] in ["parent", "content", "gpu"]:
                        process_field = processes_field["name"]
                        for type_field in processes_field["fields"]:
                            if type_field["name"] == scalar_type:
                                scalars_fields.append({"scalars": type_field, "process": process_field})
                                break

    if len(scalars_fields) == 0:
        return

    for scalars_and_process in scalars_fields:
        for scalar in scalars_and_process["scalars"].get("fields", {}):
            scalars_dict = None
            if "name" not in scalar:
                continue

            if scalar.get("type", "") == "INTEGER":
                scalars_dict = main_summary_scalars
            elif scalar.get("type", "") == "BOOLEAN":
                scalars_dict = main_summary_boolean_scalars
            elif scalar.get("type", "") == "RECORD":
                if scalar["fields"][1]["type"] == "BOOLEAN":
                    scalars_dict = main_summary_boolean_record_scalars
                else:
                    scalars_dict = main_summary_record_scalars

            save_scalars_by_type(
                scalars_dict,
                scalar["name"],
                scalars_and_process["process"]
            )

    # Find the intersection between relevant scalar probes
    # and those that exist in main summary
    with urllib.request.urlopen(PROBE_INFO_SERVICE) as url:
        data = json.loads(gzip.decompress(url.read()).decode())
        scalar_probes = set(
            [
                snake_case(x.replace("scalar/", ""))
                for x in data.keys()
                if x.startswith("scalar/")
            ]
        )

        return {
            "scalars": filter_scalars_dict(main_summary_scalars, scalar_probes),
            "booleans": filter_scalars_dict(main_summary_boolean_scalars, scalar_probes),
            "keyed": filter_scalars_dict(main_summary_record_scalars, scalar_probes),
            "keyed_boolean": filter_scalars_dict(main_summary_boolean_record_scalars, scalar_probes),
        }


def main(argv, out=print):
    """Print a clients_daily_scalar_aggregates query to stdout."""
    opts = vars(p.parse_args(argv[1:]))
    sql_string = ""

    if opts["agg_type"] in ("scalars", "keyed_scalars", "keyed_booleans"):
        scalar_type = (
            opts["agg_type"] if (opts["agg_type"] == "scalars") else "keyed_scalars"
        )
        scalar_probes = get_scalar_probes(scalar_type)
        sql_string = get_scalar_probes_sql_strings(scalar_probes, opts["agg_type"])
    else:
        raise ValueError(
            "agg-type must be one of scalars, keyed_scalars, keyed_booleans"
        )

    sleep(opts['wait_seconds'])
    out(
        reformat(
            generate_sql(
                opts["agg_type"],
                sql_string["probes_string"],
                sql_string.get("additional_queries", ""),
                sql_string.get("additional_partitions", ""),
                sql_string["select_clause"],
                sql_string.get("querying_table", "filtered"),
                opts["json_output"],
            )
        )
    )


if __name__ == "__main__":
    main(sys.argv)
