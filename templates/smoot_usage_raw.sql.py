#!/usr/bin/env python3
"""
Smoot metrics query generator.

The --source parameter determines where this operates on desktop
or nondesktop data. The output table contains a metrics array
where each entry correponds to a particular usage criterion and
contains a series of structs representing different points in time.

The "daily" metrics include all profiles from the given day in the
source table and may represent some history of the preceeding days
per the methodology of clients_last_seen where we carry over the
most recent observation for 28 days.

The "1 week post-profile" and "2-week post-profile" structs give us a
way to express metrics that depend on activity in a forward-looking
window rather than a backwards-looking window. The 1 week metrics
consider only profiles that are exactly 6 days old; this is the day on
which we can calculate metrics like how many profiles satisfied a given
usage criterion in their first week. But we generally want to associate
these metrics with the day the profile was created, so we need to shift
the metric back by a week when presenting to the user. That responsbility
is handled by the views (such as smoot_desktop_usage) on top of these raw
tables.

The user-facing views will show null values for all 1-week metrics until
the target day is at least 7 days old. For example, 2019-01-01 will show
null values for 1-week metrics if viewed on 2019-01-06, but once 2019-01-07
values are processed, the user-facing view will have the 1-week metrics
populated.
"""

import argparse
from dataclasses import dataclass, asdict
import sys
from textwrap import dedent, indent


parser = argparse.ArgumentParser()
parser.add_argument("--source", type=str, help="source table to query", required=True)


TEMPLATE = """\
-- Query generated by: templates/smoot_usage_raw.sql.py --source {source}

WITH
  base AS (
{base_select})
  --
SELECT
  submission_date,
  COUNTIF(days_since_created_profile = 6) AS new_profiles,
  [ --{usage_structs}
  ] AS metrics,
  -- We hash client_ids into 20 buckets to aid in computing
  -- confidence intervals for mau/wau/dau sums; the particular hash
  -- function and number of buckets is subject to change in the future.
  MOD(ABS(FARM_FINGERPRINT(client_id)), 20) AS id_bucket,
  app_name,
  app_version,
  country,
  locale,
  os,
  os_version,
  channel
FROM
  base
WHERE
  client_id IS NOT NULL
  -- Reprocess all dates by running this query with --parameter=submission_date:DATE:NULL
  AND (@submission_date IS NULL OR @submission_date = submission_date)
GROUP BY
  submission_date,
  id_bucket,
  app_name,
  app_version,
  country,
  locale,
  os,
  os_version,
  channel"""  # noqa


@dataclass
class UsageCriterion:
    """Wraps a logical criterion name with a column name and generates SQL."""

    display_name: str
    col_name: str
    dau_only: bool = False

    @property
    def sql(self):
        """Return a SQL string representing metrics on this criterion."""
        text = """
        STRUCT('{display_name}' AS usage,
          STRUCT(
            COUNTIF(days_since_{col_name} < 1) AS dau,
            COUNTIF(days_since_{col_name} < 7) AS wau,
            COUNTIF(days_since_{col_name} < 28) AS mau,
            SUM(udf_bitcount_lowest_7(days_{col_name}_bits)) AS active_days_in_week
          ) AS metrics_daily,
          STRUCT(
            COUNTIF(days_since_created_profile = 6 AND udf_active_n_weeks_ago(days_{col_name}_bits, 0)) AS active_in_week_0,
            SUM(IF(days_since_created_profile = 6, udf_bitcount_lowest_7(days_{col_name}_bits), 0)) AS active_days_in_week_0
          ) AS metrics_1_week_post_new_profile,
          STRUCT(
            COUNTIF(days_since_created_profile = 13 AND udf_active_n_weeks_ago(days_{col_name}_bits, 0)) AS active_in_week_1,
            COUNTIF(days_since_created_profile = 13 AND udf_active_n_weeks_ago(days_{col_name}_bits, 1) AND udf_active_n_weeks_ago(days_{col_name}_bits, 0)) AS active_in_weeks_0_and_1
          ) AS metrics_2_week_post_new_profile)""".format(  # noqa
            **asdict(self)
        )
        if self.dau_only:
            lines = []
            for line in text.split("\n"):
                before_as, separator, after_as = line.partition(" AS ")
                if separator and (
                    after_as not in ["usage,", "dau,"]
                    and not after_as.startswith("metrics_")
                ):
                    line = "            NULL AS " + after_as
                lines.append(line)
            text = "\n".join(lines)
        return text


USAGE_CRITERIA = {
    "clients_last_seen_v1": (
        UsageCriterion("Any Firefox Desktop Activity", "seen"),
        UsageCriterion("Firefox Desktop Visited 5 URI", "visited_5_uri"),
        UsageCriterion("Firefox Desktop Opened Dev Tools", "opened_dev_tools"),
        UsageCriterion(
            "New Firefox Desktop Profile Created", "created_profile", dau_only=True
        ),
    ),
    "core_clients_last_seen_v1": (
        UsageCriterion("Any Firefox Non-desktop Activity", "seen"),
        UsageCriterion(
            "New Firefox Non-desktop Profile Created", "created_profile", dau_only=True
        ),
    ),
    "fxa_users_last_seen_v1": (
        UsageCriterion("Any Firefox Account Activity", "seen"),
        UsageCriterion("New Firefox Account Registered", "registered", dau_only=True),
    ),
}


BASE_SELECT = {
    "clients_last_seen_v1": """\
    SELECT
      * REPLACE(normalized_channel AS channel)
    FROM
      clients_last_seen_v1""",
    "core_clients_last_seen_v1": """\
    SELECT
      *,
      normalized_channel AS channel
    FROM (
      SELECT
        submission_date,
        client_id,
        days_seen_bits,
        days_since_seen,
        days_since_created_profile,
        app_name,
        os,
        osversion AS os_version,
        normalized_channel,
        campaign,
        country,
        locale,
        distribution_id,
        metadata_app_version AS app_version
      FROM
        core_clients_last_seen_v1
      UNION ALL
      SELECT
        submission_date,
        client_id,
        days_seen_bits,
        days_since_seen,
        days_since_created_profile,
        app_name,
        os,
        os_version,
        normalized_channel,
        NULL AS campaign,
        country,
        locale,
        NULL AS distribution_id,
        app_display_version AS app_version
      FROM
        glean_clients_last_seen_v1 )
    WHERE
      -- We apply this filter here rather than in the live view because this field
      -- is not normalized and there are many single pings that come in with unique
      -- nonsensical app_name values. App names are documented in
      -- https://docs.telemetry.mozilla.org/concepts/choosing_a_dataset_mobile.html#products-overview
      (STARTS_WITH(app_name, 'FirefoxReality') OR app_name IN (
        'Fenix',
        'Fennec', -- Firefox for Android and Firefox for iOS
        'Focus',
        'FirefoxConnect', -- Amazon Echo
        'FirefoxForFireTV',
        'Zerda')) -- Firefox Lite, previously called Rocket
      -- There are also many strange nonsensical entries for os, so we filter here.
      AND os IN ('Android', 'iOS')""",  # noqa
    "fxa_users_last_seen_v1": """\
    SELECT
      *,
      user_id AS client_id,
      days_since_registered AS days_since_created_profile,
      language AS locale,
      NULL AS app_name,
      NULL AS channel
    FROM
      fxa_users_last_seen_v1""",
}


def generate_sql(opts):
    """Return the text of a full SQL query based on the given opts."""
    base_select = BASE_SELECT[opts["source"]]
    usage_structs = ",".join(u.sql for u in USAGE_CRITERIA[opts["source"]])
    usage_structs = indent(dedent(usage_structs), "  ")
    return TEMPLATE.format(**locals(), **opts)


def main(argv, out=print):
    """Print a smoot query to stdout."""
    opts = parser.parse_args(argv[1:])
    out(generate_sql(vars(opts)))


if __name__ == "__main__":
    main(sys.argv)
