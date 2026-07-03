#!/usr/bin/env python3
"""
Crystal Ball flywheel refresh — the weekly outcome-scoring pass.

Runs sql/06_ledger_refresh.sql against the epocadatalake read-only DB, writes the
returned Item Quality Scores (F13) back into data/callout_ledger.csv, and appends
a line to data/ledger_drift_log.csv. No LLM in the loop — pure SQL — so it is
cheap, deterministic, and safe to run on a schedule (GitHub Actions cron) with no
interactive approval.

Env:
  DATABASE_URL   read-only Postgres connection string for epocadatalake
                 (the role only needs SELECT; this script writes to CSV, not the DB)

Usage:
  python scripts/flywheel_refresh.py            # score + write back + drift log

Exit code is 0 on success (including "no change"); non-zero only on error.
"""
import csv
import os
import re
import statistics
import sys
from datetime import date

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEDGER = os.path.join(REPO, "data", "callout_ledger.csv")
DRIFT = os.path.join(REPO, "data", "ledger_drift_log.csv")
SQL06 = os.path.join(REPO, "sql", "06_ledger_refresh.sql")

# Baseline distribution (docs/FLYWHEEL_AUTOMATION.md section 1) — drift reference.
BASELINE_MEAN = 0.824
BASELINE_SHARE_BELOW = 0.15
MEAN_DRIFT = 0.15          # retrain if |mean - baseline| >= this
SHARE_DRIFT = 0.20         # ...or if share(<0.5) moves by >= this


def connect():
    url = os.environ.get("DATABASE_URL")
    if not url:
        sys.exit("ERROR: DATABASE_URL not set (add it as a repo secret / env var).")
    try:
        import psycopg2  # type: ignore
    except ImportError:
        sys.exit("ERROR: psycopg2 not installed. `pip install psycopg2-binary`.")
    return psycopg2.connect(url)


def anchor_date(cur):
    cur.execute("SELECT max(cb_stamp) FROM crystalball.list_item;")
    return cur.fetchone()[0]  # a datetime.date


def run_score(cur, anchor):
    """Execute sql/06 with its run_date literal set to the anchor; return dict by callout_id."""
    sql = open(SQL06, encoding="utf-8").read()
    # sql/06 stamps the output with a literal `date 'YYYY-MM-DD'`; point it at the anchor.
    sql = re.sub(r"date '\d{4}-\d{2}-\d{2}'", "date '%s'" % anchor.isoformat(), sql)
    cur.execute(sql)
    cols = [d[0] for d in cur.description]
    out = {}
    for row in cur.fetchall():
        r = dict(zip(cols, row))
        out[r["callout_id"]] = r
    return out


def reordered_flag(active_months):
    if active_months is None or active_months == 0:
        return ""
    return "yes" if active_months >= 12 else "no"


def num(v):
    return "" if v is None else str(int(v)) if float(v).is_integer() else str(v)


def main():
    conn = connect()
    cur = conn.cursor()
    anchor = anchor_date(cur)
    scored = run_score(cur, anchor)
    conn.close()

    with open(LEDGER, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
        fields = list(rows[0].keys())
    for col in ("realized_units", "realized_gross", "margin_pct", "reordered", "iqs", "scored_asof"):
        if col not in fields:
            fields.append(col)

    iqs_vals = []
    matched = 0
    for row in rows:
        s = scored.get(row["callout_id"])
        if not s:
            continue
        iqs = s["iqs"]
        row["realized_units"] = num(s["units"])
        row["realized_gross"] = num(s["gross"])
        row["margin_pct"] = num(s["margin_pct"])
        row["reordered"] = reordered_flag(s["active_months"])
        row["iqs"] = "" if iqs is None else "%.3f" % float(iqs)
        row["scored_asof"] = anchor.isoformat()
        if iqs is not None:
            iqs_vals.append(float(iqs))
        if s["items_matched"] and int(s["items_matched"]) > 0:
            matched += 1

    with open(LEDGER, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)

    n = len(rows)
    mean_iqs = round(sum(iqs_vals) / len(iqs_vals), 3) if iqs_vals else 0.0
    median_iqs = round(statistics.median(iqs_vals), 3) if iqs_vals else 0.0
    share_below = round(sum(1 for v in iqs_vals if v < 0.5) / n, 3) if n else 0.0

    new_log = not os.path.exists(DRIFT)
    with open(DRIFT, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if new_log:
            w.writerow(["run_date", "n_scored", "n_matched", "mean_iqs", "median_iqs", "share_below_0_5"])
        w.writerow([anchor.isoformat(), n, matched, mean_iqs, median_iqs, share_below])

    retrain = (abs(mean_iqs - BASELINE_MEAN) >= MEAN_DRIFT) or (abs(share_below - BASELINE_SHARE_BELOW) >= SHARE_DRIFT)
    print("Flywheel refresh %s | n=%d matched=%d mean_iqs=%.3f median=%.3f share<0.5=%.3f | RETRAIN %s"
          % (anchor.isoformat(), n, matched, mean_iqs, median_iqs, share_below, "DUE" if retrain else "not due"))
    # Emit a GitHub Actions output/notice when running in CI.
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as gh:
            gh.write("retrain_due=%s\n" % ("true" if retrain else "false"))
            gh.write("summary=%s mean_iqs=%.3f retrain=%s\n" % (anchor.isoformat(), mean_iqs, retrain))


if __name__ == "__main__":
    main()
