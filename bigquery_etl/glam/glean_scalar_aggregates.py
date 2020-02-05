#!/usr/bin/env python3
"""clients_daily_scalar_aggregates query generator."""
import argparse
import json
import subprocess
import sys
import urllib.request
from typing import Dict, List

from bigquery_etl.format_sql.formatter import reformat

parser = argparse.ArgumentParser()
parser.add_argument(
    "--agg-type", type=str, help="One of scalar/keyed-scalar", required=True
)
parser.add_argument(
    "--no-parameterize", action="store_true", help="Generate a query without parameters"
)
parser.add_argument(
    "--table-id",
    type=str,
    help="Name of Glean table",
    default="org_mozilla_fenix_stable.metrics_v1",
)

ATTRIBUTES = ",".join(
    ["client_id", "submission_date", "os", "app_version", "app_build_id", "channel"]
)


def generate_sql(
    table_id,
    agg_type,
    aggregates,
    additional_queries,
    additional_partitions,
    select_clause,
    querying_table,
    no_parameterize=False,
):
    """Create a SQL query for the clients_daily_scalar_aggregates dataset."""
    # TODO: What is the right granularity for Fenix versioning?
    # TODO: Channels have a different meaning in Glean, what should the set be?

    # If set to 1 day, then runs of copy_deduplicate may not be done yet
    date = (
        "date_sub(current_date, interval 2 day)"
        if no_parameterize
        else "@submission_date"
    )
    return f"""\
        -- Query generated by:
        -- python3 -m bigquery_etl.glam.glean_scalar_aggregates --agg-type {agg_type}
        WITH filtered AS (
        SELECT
            *,
            DATE(submission_timestamp) AS submission_date,
            client_info.client_id,
            SPLIT(client_info.app_display_version, '.')[OFFSET(0)] AS app_version,
            client_info.os AS os,
            client_info.app_build AS app_build_id,
            client_info.app_channel AS channel
        FROM
            `moz-fx-data-shared-prod.{table_id}`
        WHERE
            DATE(submission_timestamp) = {date}
            AND client_info.app_channel IN ("release", "fenixProduction")
            AND client_info.client_id IS NOT NULL
        ),
        {additional_queries}
        aggregated AS (
            SELECT
                {ATTRIBUTES},
                {aggregates}
            FROM {querying_table}
            GROUP BY
                {ATTRIBUTES}
                {"," if additional_partitions else ""}
                {additional_partitions})

            {select_clause}
        """


def _get_generic_keyed_scalar_sql(probes, value_type):
    probes_struct = []
    for metric_type, probes in probes.items():
        for probe in probes:
            probes_struct.append(
                f"('{probe}', '{metric_type}', metrics.{metric_type}.{probe})"
            )

    probes_struct.sort()
    probes_arr = ",\n".join(probes_struct)

    additional_queries = f"""
        grouped_metrics AS
          (SELECT
            {ATTRIBUTES},
            ARRAY<STRUCT<
                name STRING,
                type STRING,
                value ARRAY<STRUCT<key STRING, value {value_type}>>
            >>[
              {probes_arr}
            ] as metrics
          FROM filtered),

          flattened_metrics AS
            (SELECT
              {ATTRIBUTES},
              metrics.name AS metric,
              metrics.type as metric_type,
              value.key AS key,
              value.value AS value
            FROM grouped_metrics
            CROSS JOIN UNNEST(metrics) AS metrics,
            UNNEST(metrics.value) AS value),
    """

    return {
        "additional_queries": additional_queries,
        "additional_partitions": "metric, metric_type, key",
        "querying_table": "flattened_metrics",
    }


def get_keyed_scalar_probes_sql_string(probes):
    """Put together the subsets of SQL required to query keyed scalars."""
    sql_strings = _get_generic_keyed_scalar_sql(probes, "INT64")
    sql_strings[
        "probes_string"
    ] = """
        metric,
        metric_type,
        key,
        MAX(value) AS max,
        MIN(value) AS min,
        AVG(value) AS avg,
        SUM(value) AS sum,
        IF(MIN(value) IS NULL, NULL, COUNT(*)) AS count
    """

    sql_strings[
        "select_clause"
    ] = f"""
        SELECT
            {ATTRIBUTES},
            ARRAY_CONCAT_AGG(ARRAY<STRUCT<
                metric STRING,
                metric_type STRING,
                key STRING,
                agg_type STRING,
                value FLOAT64
            >>
                [
                    (metric, metric_type, key, 'max', max),
                    (metric, metric_type, key, 'min', min),
                    (metric, metric_type, key, 'avg', avg),
                    (metric, metric_type, key, 'sum', sum),
                    (metric, metric_type, key, 'count', count)
                ]
            ) AS scalar_aggregates
        FROM aggregated
        GROUP BY
            {ATTRIBUTES}
    """
    return sql_strings


def get_scalar_probes_sql_strings(
    probes: Dict[str, List[str]], scalar_type: str
) -> Dict[str, str]:
    """Put together the subsets of SQL required to query scalars or booleans."""
    if scalar_type == "keyed_scalars":
        return get_keyed_scalar_probes_sql_string(
            {"labeled_counter": probes["labeled_counter"]}
        )

    probe_structs = []
    for probe in probes.pop("boolean", []):
        probe_structs.append(
            (
                f"('{probe}', 'boolean', '', 'false', "
                f"SUM(case when metrics.boolean.{probe} = False "
                "THEN 1 ELSE 0 END))"
            )
        )
        probe_structs.append(
            (
                f"('{probe}', 'boolean', '', 'true', "
                f"SUM(case when metrics.boolean.{probe} = True "
                "THEN 1 ELSE 0 END))"
            )
        )

    for metric_type, probes in probes.items():
        for probe in probes:
            for agg_func in ["max", "avg", "min", "sum"]:
                probe_structs.append(
                    (
                        f"('{probe}', '{metric_type}', '', '{agg_func}', "
                        f"{agg_func}(CAST(metrics.{metric_type}.{probe} AS INT64)))"
                    )
                )
            probe_structs.append(
                f"('{probe}', '{metric_type}', '', 'count', "
                f"IF(MIN(metrics.{metric_type}.{probe}) IS NULL, NULL, COUNT(*)))"
            )

    probe_structs.sort()
    probes_arr = ",\n".join(probe_structs)
    probes_string = f"""
            ARRAY<STRUCT<
                metric STRING,
                metric_type STRING,
                key STRING,
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


def get_schema(table: str, project: str = "moz-fx-data-shared-prod"):
    """Return the dictionary representation of the BigQuery table schema.
    This returns types in the legacy SQL format.
    """
    process = subprocess.Popen(
        ["bq", "show", "--schema", "--format=json", f"{project}:{table}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    stdout, stderr = process.communicate()
    if process.returncode > 0:
        raise Exception(
            f"Call to bq exited non-zero: {process.returncode}", stdout, stderr
        )
    return json.loads(stdout)


def get_scalar_probes(schema: Dict, scalar_type: str) -> Dict[str, List[str]]:
    """Find all scalar probes in a Glean table.

    Metric types are defined in the Glean documentation found here:
    https://mozilla.github.io/glean/book/user/metrics/index.html
    """
    metric_type_set = {
        "scalars": ["boolean", "counter", "quantity"],
        "keyed_scalars": ["labeled_counter"],
    }
    scalars = {metric_type: [] for metric_type in metric_type_set[scalar_type]}

    # Iterate over every element in the schema under the metrics section and
    # collect a list of metric names.
    for root_field in schema:
        if root_field["name"] != "metrics":
            continue
        for metric_field in root_field["fields"]:
            metric_type = metric_field["name"]
            if metric_type not in metric_type_set[scalar_type]:
                continue
            for field in metric_field["fields"]:
                scalars[metric_type].append(field["name"])
    return scalars


def main(argv, out=print):
    """Print a clients_daily_scalar_aggregates query to stdout."""
    opts = vars(parser.parse_args(argv[1:]))
    sql_string = ""

    scalar_type = opts["agg_type"]
    if not scalar_type in ("scalars", "keyed_scalars"):
        raise ValueError("agg-type must be one of scalars, keyed_scalars")

    table_id = opts["table_id"]
    schema = get_schema(table_id)
    scalar_probes = get_scalar_probes(schema, scalar_type)
    sql_string = get_scalar_probes_sql_strings(scalar_probes, scalar_type)

    out(
        reformat(
            generate_sql(
                table_id,
                scalar_type,
                sql_string["probes_string"],
                sql_string.get("additional_queries", ""),
                sql_string.get("additional_partitions", ""),
                sql_string["select_clause"],
                sql_string.get("querying_table", "filtered"),
                no_parameterize=opts["no_parameterize"],
            )
        )
    )


if __name__ == "__main__":
    main(sys.argv)
