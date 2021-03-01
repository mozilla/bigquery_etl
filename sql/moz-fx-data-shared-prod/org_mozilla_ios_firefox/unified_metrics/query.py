"""Generate a query for unifying legacy metrics and glean metrics.

This approach is required because the order of columns is significant in order
to be able to union two tables, even if the set of columns are the same."""

import requests
import json
from bigquery_etl.format_sql.formatter import reformat
from google.cloud import bigquery, exceptions
import io


def get_columns(schema):
    """Return a list of columns corresponding to the schema.

    Modified from https://github.com/mozilla-services/mozilla-pipeline-schemas/blob/c2dae92a7ed73e4774a897bc4d2a6a8608875339/mozilla_pipeline_schemas/utils.py#L30-L43
    """

    def traverse(prefix, columns):
        res = []
        for node in columns:
            name = node["name"]
            dtype = node["type"]
            # we consider a repeated field a leaf node, and sorted for our purposes
            if dtype == "RECORD" and node["mode"] != "REPEATED":
                res += traverse(f"{prefix}.{name}", node["fields"])
            else:
                res += [f"{prefix}.{name} {dtype}"]
        return res

    res = traverse("root", schema)
    return sorted(res)


def generate_query(columns, table):
    """Generate a SQL query given column names.

    We construct a query that selects columns into nested structs. Naive selection
    of all the columns will strip the namespace from the columns.
    """

    # Build a string that contains the selected columns. We take the set of
    # columns and split them up by namespace. Each namespace is put inside of a
    # STRUCT call. For example, foo.a and foo.b will be translated into a
    # `STRUCT(foo.a, foo.b) as foo` nested column.
    acc = ""

    # Maintain the last element in the columns to determine when a transition
    # must be made.
    prev = []

    # Iterate over the sorted set of columns. This ensures that columns are
    # grouped together correctly. Every time the column goes into a namespace,
    # we push an opening struct statement onto the string. Every time we
    # complete nested struct, we close out the string by aliasing the struct to
    # the namespace.
    for col in sorted(columns):
        split = col.split(".")
        # check if we go deeper
        if len(split) > 1 and len(split) > len(prev):
            # the number of times to start nesting
            if len(prev) == 0:
                k = len(split) - 1
            else:
                k = len(split) - len(prev)
            acc += "struct(" * k
        # sometimes we have two structs that are the same depth e.g. metrics
        if len(split) > 1 and len(split) == len(prev) and split[-2] != prev[-2]:
            # ensure that we are not ending a struct with a comma
            acc = acc.rstrip(",")
            acc += f") as {prev[-2]},"
            acc += "struct("
        # pop out of the struct
        if len(split) < len(prev):
            diff = len(prev) - len(split)
            # ignore the leaf
            prev.pop()
            for _ in range(diff):
                c = prev.pop()
                acc = acc.rstrip(",")
                acc += f") as {c},"
        acc += f"{col},"
        prev = split
    # clean up any columns
    if len(prev) > 1:
        prev.pop()
        for c in reversed(prev):
            acc = acc.rstrip(",")
            acc += f") as {c},"
    acc = acc.rstrip(",")

    return reformat(f"select {acc} from `{table}`")


def main():
    # get the most schema deploy (to the nearest 15 minutes)
    deploys_url = (
        "https://protosaur.dev/mps-deploys/data/mozilla_pipeline_schemas/deploys.json"
    )
    resp = requests.get(deploys_url)
    deploys_data = resp.json()
    # get the last element that has reached production
    last_prod_deploy = [
        row
        for row in sorted(deploys_data, key=lambda x: x["submission_timestamp"])
        if row["project"] == "moz-fx-data-shared-prod"
    ][-1]
    print(f"last deploy: {last_prod_deploy}")

    # get the schema corresponding to the last commit
    commit_hash = last_prod_deploy["commit_hash"]
    schema_url = (
        "https://raw.githubusercontent.com/mozilla-services/mozilla-pipeline-schemas/"
        f"{commit_hash}/schemas/org-mozilla-ios-firefox/metrics/metrics.1.bq"
    )
    resp = requests.get(schema_url)
    schema = resp.json()
    column_summary = get_columns(schema)

    print(json.dumps(column_summary, indent=2))
    """
    The columns take on the following form:

    "root.additional_properties STRING",
    "root.client_info.android_sdk_version STRING",
    "root.client_info.app_build STRING",
    ...

    This will need to be processed yet again so we can query via bigquery
    """

    bq = bigquery.Client()
    legacy_table = (
        "moz-fx-data-shared-prod.org_mozilla_ios_firefox_derived.legacy_metrics_v1"
    )
    table = bq.get_table(legacy_table)
    table.schema = bq.schema_from_json(io.StringIO(json.dumps(schema)))
    bq.update_table(table, ["schema"])

    stripped = [c.split()[0].lstrip("root.") for c in column_summary]
    query_glean = generate_query(
        ['"glean" as telemetry_system', *stripped],
        "mozdata.org_mozilla_ios_firefox.metrics",
    )
    query_legacy = generate_query(
        ['"legacy" as telemetry_system', *stripped],
        legacy_table,
    )
    view_body = reformat(f"{query_glean} UNION ALL {query_legacy}")
    view_id = "moz-fx-data-shared-prod.org_mozilla_ios_firefox.unified_metrics"
    try:
        bq.delete_table(bq.get_table(view_id))
    except exceptions.NotFound:
        pass
    view = bigquery.Table(view_id)
    view.view_query = view_body
    bq.create_table(view)
    print(f"updated view at {view_id}")


def test_generate_query_simple():
    columns = ["a", "b"]
    res = generate_query(columns, "test")
    expect = reformat("select a, b from `test`")
    assert res == expect, f"expected:\n{expect}\ngot:\n{res}"


def test_generate_query_nested():
    columns = ["a", "b.c", "b.d"]
    res = generate_query(columns, "test")
    expect = reformat("select a, struct(b.c, b.d) as b from `test`")
    assert res == expect, f"expected:\n{expect}\ngot:\n{res}"


def test_generate_query_nested_deep_skip():
    columns = ["b.c.e", "b.d.f"]
    res = generate_query(columns, "test")
    expect = reformat(
        """
    select struct(
        struct(
            b.c.e
        ) as c,
        struct(
            b.d.f
        ) as d
    ) as b
    from `test`
    """
    )
    assert res == expect, f"expected:\n{expect}\ngot:\n{res}"


def test_generate_query_nested_deep():
    columns = ["a.b", "a.c", "a.d.x.y.e", "a.d.x.y.f", "g"]
    res = generate_query(columns, "test")
    expect = reformat(
        """
        select struct(
            a.b,
            a.c,
            struct(
                struct(
                    struct(
                        a.d.x.y.e,
                        a.d.x.y.f
                    ) as y
                ) as x
            ) as d
        ) as a,
        g
        from `test`
    """
    )
    assert res == expect, f"expected:\n{expect}\ngot:\n{res}"


if __name__ == "__main__":
    test_generate_query_simple()
    test_generate_query_nested()
    test_generate_query_nested_deep_skip()
    test_generate_query_nested_deep()
    main()
