# SQL

The analysis from the notebook, rewritten as SQL. PostgreSQL dialect; DuckDB runs the same files unchanged.

| File | What it does |
|---|---|
| `00_schema.sql` | tables for the committed CSV files and for the raw user-day file |
| `01_raw_to_marts.sql` | raw data quality, user-level and daily marts, retention two ways (first active day in the window as in the notebook, and from install with censoring), row-by-row reconciliation with the notebook output. Needs `data/ab_test_data.csv` |
| `02_summary.sql` | users, payers, conversion, ARPU, ARPPU, engagement per group; SRM check |
| `03_significance.sql` | the 11 comparisons: Welch t-tests on per-user means, z-tests on proportions, 95% CI, Holm correction |
| `04_reaudit_active_days.sql` | active-days distribution, cumulative shares, bands 1 to 7, the disengaging segment |
| `05_revenue_distribution.sql` | payer revenue percentiles, top 1% and 10% revenue share, ARPU with revenue capped at p99 |
| `06_daily_trends.sql` | cumulative revenue, 7-day ARPDAU, daily lift, DAU slope |
| `07_tableau_extracts.sql` | `tableau_*` views, written to `tableau/*.csv` |

## Run

DuckDB, no database server needed:

```bash
pip install duckdb
python sql/run.py                               # analysis, checks, Tableau extracts
python sql/run.py --raw data/ab_test_data.csv   # also the raw-file marts
python sql/run.py --quiet                       # checks and extracts only
```

PostgreSQL, from the repository root:

```bash
createdb abtest
psql -d abtest -f sql/run_postgres.psql
```

## Notes

- `group` is a reserved word, so the column is `ab_group` in every table.
- p-values use the normal approximation to the t and z distributions (Abramowitz and Stegun 26.2.17). With thousands of users per group the gap to scipy is under 1e-6.
- Display queries round through `numeric(20, 6)`: plain `numeric` means `DECIMAL(18,3)` in DuckDB and would cut digits before rounding.
- Integer division differs between the two engines, so every ratio has a float on one side.
