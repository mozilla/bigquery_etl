r"""Metric counting.

```bash
python3 -m bigquery_etl.glam.glean_metric_counts

diff \
    <(cat sql/telemetry_derived/clients_histogram_probe_counts_v1/query.sql) \
    <(python3 -m bigquery_etl.glam.glean_metric_counts)
```
"""
from itertools import combinations
from typing import List

from jinja2 import Environment, PackageLoader

from bigquery_etl.format_sql.formatter import reformat


def render_query(
    header: str,
    source_table: str,
    attributes: List[str],
    aggregate_attributes: str,
    aggregate_grouping: str,
    **kwargs,
) -> str:
    """Render the main query."""
    env = Environment(loader=PackageLoader("bigquery_etl", "glam/templates"))
    sql = env.get_template("metric_counts_v1.sql")

    # include attributes included and excluded from grouping set
    attribute_combinations = []
    for subset_size in reversed(range(len(attributes) + 1)):
        for grouping in combinations(attributes, subset_size):
            hidden = list(sorted(set(attributes) - set(grouping)))
            attribute_combinations.append((grouping, hidden))

    return reformat(
        sql.render(
            header=header,
            source_table=source_table,
            attribute_combinations=attribute_combinations,
            aggregate_attributes=aggregate_attributes,
            aggregate_grouping=aggregate_grouping,
        )
    )


def telemetry_variables():
    """Variables for metric_bucketing."""
    return dict(
        source_table="clients_histogram_bucket_counts_v1",
        attributes=["os", "app_version", "app_build_id", "channel"],
        aggregate_attributes="""
            metric,
            metric_type,
            key,
            process
        """,
        aggregate_grouping="""
            client_agg_type,
            first_bucket,
            last_bucket,
            num_buckets
        """,
    )


print(render_query(header="-- generated by:", **telemetry_variables()))
