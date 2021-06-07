"""Generic utility functions."""
import os
import random
import re
import string
import logging
from typing import List
from pathlib import Path

from jinja2 import Environment, PackageLoader
from bigquery_etl.format_sql.formatter import reformat

# Search for all camelCase situations in reverse with arbitrary lookaheads.
REV_WORD_BOUND_PAT = re.compile(
    r"""
    \b                                  # standard word boundary
    |(?<=[a-z][A-Z])(?=\d*[A-Z])        # A7Aa -> A7|Aa boundary
    |(?<=[a-z][A-Z])(?=\d*[a-z])        # a7Aa -> a7|Aa boundary
    |(?<=[A-Z])(?=\d*[a-z])             # a7A -> a7|A boundary
    """,
    re.VERBOSE,
)
SQL_DIR = "sql/"


def snake_case(line: str) -> str:
    """Convert a string into a snake_cased string."""
    # replace non-alphanumeric characters with spaces in the reversed line
    subbed = re.sub(r"[^\w]|_", " ", line[::-1])
    # apply the regex on the reversed string
    words = REV_WORD_BOUND_PAT.split(subbed)
    # filter spaces between words and snake_case and reverse again
    return "_".join([w.lower() for w in words if w.strip()])[::-1]


def project_dirs(project_id=None) -> List[str]:
    """Return all project directories."""
    if project_id is None:
        return [
            os.path.join(SQL_DIR, project_dir) for project_dir in os.listdir(SQL_DIR)
        ]
    else:
        return [os.path.join(SQL_DIR, project_id)]


def random_str(length: int = 12) -> str:
    """Return a random string of the specified length."""
    return "".join(random.choice(string.ascii_lowercase) for i in range(length))


def render(sql_filename, format=True, template_folder="glean_usage", **kwargs) -> str:
    """Render a given template query using Jinja."""
    env = Environment(
        loader=PackageLoader("bigquery_etl", f"{template_folder}/templates")
    )
    main_sql = env.get_template(sql_filename)
    rendered = main_sql.render(**kwargs)
    if format:
        rendered = reformat(rendered)
    return rendered


def write_sql(output_dir, full_table_id, basename, sql):
    """Write out a query to a location based on the table ID.

    :param output_dir:    Base target directory (probably sql/moz-fx-data-shared-prod/)
    :param full_table_id: Table ID in project.dataset.table form
    :param basename:      The name to give the written file (like query.sql)
    :param sql:           The query content to write out
    """
    d = Path(os.path.join(output_dir, *list(full_table_id.split(".")[-2:])))
    d.mkdir(parents=True, exist_ok=True)
    target = d / basename
    logging.info(f"Writing {target}")
    with target.open("w") as f:
        f.write(sql)
        f.write("\n")
