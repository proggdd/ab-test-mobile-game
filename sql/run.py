"""Run the SQL in this folder on the committed CSV files with DuckDB.

    pip install duckdb
    python sql/run.py                               # analysis, checks, Tableau extracts
    python sql/run.py --raw data/ab_test_data.csv   # also rebuild the marts from the raw file

The queries are written for PostgreSQL and DuckDB runs them unchanged.
For PostgreSQL itself use sql/run_postgres.psql (see sql/README.md).
"""
import argparse
import json
import os
import sys

import duckdb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQL_DIR = os.path.join(ROOT, "sql")
DATA = os.path.join(ROOT, "data")
TABLEAU = os.path.join(ROOT, "tableau")
ANALYSIS = ["02_summary.sql", "03_significance.sql", "04_reaudit_active_days.sql",
            "05_revenue_distribution.sql", "06_daily_trends.sql", "07_tableau_extracts.sql"]


def statements(name):
    """Statements of a .sql file. Full-line comments are dropped; no file here
    has a semicolon inside a string or a comment."""
    with open(os.path.join(SQL_DIR, name), encoding="utf-8") as f:
        lines = [l for l in f.read().splitlines() if not l.strip().startswith("--")]
    return [s.strip() for s in "\n".join(lines).split(";") if s.strip()]


def run_file(con, name, show=True):
    print("\n== %s" % name)
    for st in statements(name):
        if st.upper().startswith("SELECT") and show:
            con.sql(st).show(max_width=200)
        else:
            con.execute(st)


def load(con, raw_path=None):
    for st in statements("00_schema.sql"):
        con.execute(st)
    for table, fname in (("user_level", "user_level.csv"), ("daily", "daily.csv"),
                         ("retention_src", "retention.csv")):
        con.execute("COPY %s FROM '%s' (HEADER)" % (table, os.path.join(DATA, fname).replace("\\", "/")))
    if raw_path:
        con.execute("""
            INSERT INTO raw_user_day
            SELECT user_id, "group", date, first_seen, revenue, sessions, time_played, transactions
            FROM read_csv(?, header = true)""", [raw_path])


def checks(con):
    """SQL results against what the notebook (pandas, scipy, statsmodels) saved."""
    results = []

    def check(name, got, expected, tol):
        ok = abs(got - expected) <= tol
        results.append(ok)
        print("%-4s %-46s sql=%-14.6g notebook=%-14.6g" % ("OK" if ok else "DIFF", name, got, expected))

    print("\n== checks against the notebook outputs")
    with open(os.path.join(ROOT, "output", "summary_table.csv"), encoding="utf-8") as f:
        header, *rows = [line.strip().split(",") for line in f if line.strip()]
    for row in rows:
        nb = dict(zip(header, row))
        sql = con.sql("SELECT users, paying_users, conversion_pct, arpu, arppu, avg_sessions, "
                      "avg_time_min, avg_active_days FROM summary WHERE ab_group = ?",
                      params=[nb["group"]]).fetchone()
        for i, col in enumerate(["users", "paying_users", "conversion_%", "ARPU", "ARPPU",
                                 "avg_sessions", "avg_time_min", "avg_active_days"]):
            check("summary %s %s" % (nb["group"], col), float(sql[i]), float(nb[col]), 1e-3)

    for day, p in con.sql("SELECT day, p FROM retention_src ORDER BY day").fetchall():
        got = con.sql("SELECT p_value FROM significance_tests WHERE metric = ?",
                      params=["D%d retention, %%" % day]).fetchone()[0]
        check("retention D%d p-value" % day, got, p, 1e-6)

    with open(os.path.join(ROOT, "docs", "data.json"), encoding="utf-8") as f:
        meta = json.load(f)
    check("SRM chi2", con.sql("SELECT chi2 FROM srm_check").fetchone()[0], meta["srm"]["chi2"], 1e-4)
    check("SRM p-value", con.sql("SELECT p_value FROM srm_check").fetchone()[0], meta["srm"]["p"], 1e-6)
    check("ARPU p-value (Welch)",
          con.sql("SELECT p_value FROM significance_tests WHERE metric = 'ARPU, $'").fetchone()[0],
          meta["revenue"]["arpu"]["p"], 1e-6)
    check("total revenue",
          con.sql("SELECT sum(total_revenue) FROM summary").fetchone()[0],
          meta["meta"]["total_revenue"], 0.5)
    return all(results)


def export_tableau(con):
    os.makedirs(TABLEAU, exist_ok=True)
    views = [r[0] for r in con.sql(
        "SELECT view_name FROM duckdb_views() WHERE view_name LIKE 'tableau_%' ORDER BY 1").fetchall()]
    print("\n== Tableau extracts")
    for v in views:
        path = os.path.join(TABLEAU, v[len("tableau_"):] + ".csv")
        con.execute("COPY (SELECT * FROM %s) TO '%s' (HEADER, DELIMITER ',')" % (v, path.replace("\\", "/")))
        n = con.sql("SELECT count(*) FROM %s" % v).fetchone()[0]
        print("%-28s %6d rows -> %s" % (v, n, os.path.relpath(path, ROOT)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", help="path to data/ab_test_data.csv, the raw user-day file")
    ap.add_argument("--quiet", action="store_true", help="do not print query results")
    a = ap.parse_args()

    con = duckdb.connect()
    load(con, a.raw)
    if a.raw:
        run_file(con, "01_raw_to_marts.sql", show=not a.quiet)
    for name in ANALYSIS:
        run_file(con, name, show=not a.quiet)
    ok = checks(con)
    export_tableau(con)
    print("\nall checks passed" if ok else "\nsome checks differ, see DIFF lines above")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
