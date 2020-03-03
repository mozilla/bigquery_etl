"""clients_daily_histogram_aggregates query generator."""
import argparse
from jinja2 import Environment, PackageLoader

from bigquery_etl.format_sql.formatter import reformat


def render_main(**kwargs):
    """Create a SQL query for the clients_daily_histogram_aggregates dataset."""
    env = Environment(loader=PackageLoader("bigquery_etl", "glam/templates"))
    main_sql = env.get_template("clients_histogram_bucket_counts_v1.sql")
    return reformat(main_sql.render(**kwargs))


def glean_variables():
    attributes_list = ["os", "app_version", "app_build_id", "channel"]
    metric_attributes_list = ["latest_version", "metric", "metric_type", "key", "agg_type"]
    return dict(
        attributes_list=attributes_list,
        attributes=",".join(attributes_list),
        metric_attributes_list=metric_attributes_list,
        metric_attributes=",".join(metric_attributes_list),
    )


def main():
    """Print a rendered query to stdout."""
    header = "-- Query generated by: python3 -m bigquery_etl.glam.clients_histogram_bucket_counts"

    print(render_main(header=header, **glean_variables()))


if __name__ == "__main__":
    main()
