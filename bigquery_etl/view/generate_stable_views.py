"""
Generate user-facing views on top of stable tables.

If there are multiple versions of a given document type, the generated view
references only the most recent.

Note that no view will be generated if a corresponding view is already
present in the target directory, which allows manual overrides of views by
checking them into the sql/ tree of the default branch of the repository.
"""

import json
import logging
import tarfile
import tempfile
import urllib.request
from argparse import ArgumentParser
from dataclasses import dataclass
from functools import partial
from io import BytesIO
from itertools import groupby
from multiprocessing.pool import ThreadPool
from pathlib import Path
from typing import List

from bigquery_etl.dryrun import DryRun
from bigquery_etl.format_sql.formatter import reformat
from bigquery_etl.util import standard_args

SCHEMAS_URI = (
    "https://github.com/mozilla-services/mozilla-pipeline-schemas"
    "/archive/generated-schemas.tar.gz"
)

SKIP_PREFIXES = (
    "pioneer",
    "rally",
)

VIEW_QUERY_TEMPLATE = """\
-- Generated by bigquery_etl.view.generate_stable_views
CREATE OR REPLACE VIEW
  `{full_view_id}`
AS
SELECT
  * REPLACE(
    {replacements})
FROM
  `{target}`
"""

VIEW_METADATA_TEMPLATE = """\
# Generated by bigquery_etl.view.generate_stable_views
---
friendly_name: Historical Pings for `{document_namespace}/{document_type}`
description: |-
  A historical view of pings sent for the
  `{document_namespace}/{document_type}`
  document type.

  This view is guaranteed to contain only complete days
  (per `submission_timestamp`)
  and to contain only one row per distinct `document_id` within a given date.

  Clustering fields: `normalized_channel`, `sample_id`
"""

parser = ArgumentParser(description=__doc__)
parser.add_argument(
    "--sql-dir", default="sql/", help="The path where generated SQL files are stored."
)
parser.add_argument(
    "--target-project",
    default="moz-fx-data-shared-prod",
    help="The project where the stable tables live.",
)
parser.add_argument(
    "--no-dry-run",
    action="store_false",
    default=True,
    dest="dry_run",
    help="Don't use dry run to check whether stable tables actually exist.",
)
standard_args.add_log_level(parser)
standard_args.add_parallelism(parser)


@dataclass
class SchemaFile:
    """Container for metadata about a JSON schema and corresponding BQ table."""

    schema_id: str
    bq_dataset_family: str
    bq_table: str
    document_namespace: str
    document_type: str
    document_version: int

    @property
    def bq_table_unversioned(self):
        """Return table_id with version suffix stripped."""
        return "_".join(self.bq_table.split("_")[:-1])

    @property
    def stable_table(self):
        """Return BQ stable table name in <dataset>.<table> form."""
        return f"{self.bq_dataset_family}_stable.{self.bq_table}"

    @property
    def user_facing_view(self):
        """Return user-facing view name in <dataset>.<view> form."""
        return f"{self.bq_dataset_family}.{self.bq_table_unversioned}"

    @property
    def sortkey(self):
        """Return variant of stable_table with zero-padded version for sorting."""
        return (
            "_".join(self.stable_table.split("_")[:-1]) + f"{self.document_version:04d}"
        )


def write_view_if_not_exists(
    target_project: str, sql_dir: Path, schema: SchemaFile, dry_run: bool
):
    """If a view.sql does not already exist, write one to the target directory."""
    target_dir = (
        sql_dir
        / target_project
        / schema.bq_dataset_family
        / schema.bq_table_unversioned
    )
    target_file = target_dir / "view.sql"

    if target_file.exists():
        return

    # Exclude doctypes maintained in separate projects.
    for prefix in SKIP_PREFIXES:
        if schema.bq_dataset_family.startswith(prefix):
            return

    full_source_id = f"{target_project}.{schema.stable_table}"
    full_view_id = f"{target_project}.{schema.user_facing_view}"
    replacements = ["mozfun.norm.metadata(metadata) AS metadata"]
    if schema.schema_id == "moz://mozilla.org/schemas/glean/ping/1":
        replacements += ["mozfun.norm.glean_ping_info(ping_info) AS ping_info"]
        if schema.bq_table == "baseline_v1":
            replacements += [
                "mozfun.norm.glean_baseline_client_info"
                "(client_info, metrics) AS client_info"
            ]
        if (
            schema.bq_dataset_family == "org_mozilla_fenix"
            and schema.bq_table == "metrics_v1"
        ):
            # todo: use mozfun udfs
            replacements += [
                "mozdata.udf.normalize_fenix_metrics"
                "(client_info.telemetry_sdk_build, metrics)"
                " AS metrics"
            ]
        if schema.bq_dataset_family == "firefox_desktop":
            # FOG does not provide an app_name, so we inject the one that
            # people already associate with desktop Firefox per bug 1672191.
            replacements += [
                "'Firefox' AS normalized_app_name",
            ]
    elif schema.schema_id.startswith("moz://mozilla.org/schemas/main/ping/"):
        replacements += ["mozdata.udf.normalize_main_payload(payload) AS payload"]
    replacements_str = ",\n    ".join(replacements)
    full_sql = reformat(
        VIEW_QUERY_TEMPLATE.format(
            target=full_source_id,
            replacements=replacements_str,
            full_view_id=full_view_id,
        )
    )
    if dry_run:
        with tempfile.TemporaryDirectory() as tdir:
            tfile = Path(tdir) / "view.sql"
            with tfile.open("w") as f:
                f.write(full_sql)
            print(f"Dry running {schema.user_facing_view}")
            dryrun = DryRun(str(tfile))
            if 404 in [e.get("code") for e in dryrun.errors()]:
                print(
                    f"Not creating {schema.user_facing_view} since"
                    " stable table does not exist"
                )
                return
    print(f"Creating {target_file}")
    target_dir.mkdir(parents=True, exist_ok=True)
    with target_file.open("w") as f:
        f.write(full_sql)
    metadata_content = VIEW_METADATA_TEMPLATE.format(
        document_namespace=schema.document_namespace,
        document_type=schema.document_type,
    )
    metadata_file = target_dir / "metadata.yaml"
    if not metadata_file.exists():
        with metadata_file.open("w") as f:
            f.write(metadata_content)


def get_stable_table_schemas() -> List[SchemaFile]:
    """Fetch last schema metadata per doctype by version."""
    with urllib.request.urlopen(SCHEMAS_URI) as f:
        tarbytes = BytesIO(f.read())

    schemas = []
    with tarfile.open(fileobj=tarbytes, mode="r:gz") as tar:
        for tarinfo in tar:
            if tarinfo.name.endswith(".schema.json"):
                *_, document_namespace, document_type, basename = tarinfo.name.split(
                    "/"
                )
                version = int(basename.split(".")[1])
                schema = json.load(tar.extractfile(tarinfo.name))  # type: ignore
                pipeline_meta = schema.get("mozPipelineMetadata", None)
                if pipeline_meta is None:
                    continue
                schemas.append(
                    SchemaFile(
                        schema_id=schema.get("$id", ""),
                        bq_dataset_family=pipeline_meta["bq_dataset_family"],
                        bq_table=pipeline_meta["bq_table"],
                        document_namespace=document_namespace,
                        document_type=document_type,
                        document_version=version,
                    )
                )
    schemas = sorted(
        schemas,
        key=lambda t: f"{t.document_namespace}/{t.document_type}/{t.document_version:03d}",
    )
    return [
        last
        for k, (*_, last) in groupby(
            schemas, lambda t: f"{t.document_namespace}/{t.document_type}"
        )
    ]


def main():
    """
    Generate view definitions.

    Metadata about document types is from the generated-schemas branch
    of mozilla-pipeline-schemas. We write out generated views for each
    document type in parallel.

    There is a performance bottleneck here due to the need to dry-run each
    view to ensure the source table actually exists.
    """
    args = parser.parse_args()

    # set log level
    try:
        logging.basicConfig(level=args.log_level, format="%(levelname)s %(message)s")
    except ValueError as e:
        parser.error(f"argument --log-level: {e}")

    schemas = get_stable_table_schemas()

    with ThreadPool(args.parallelism) as pool:
        pool.map(
            partial(
                write_view_if_not_exists,
                args.target_project,
                Path(args.sql_dir),
                dry_run=args.dry_run,
            ),
            schemas,
            chunksize=1,
        )


if __name__ == "__main__":
    main()
