# Tableau extracts

Flat files for the Tableau Public dashboard, written by `python sql/run.py` from the `tableau_*` views in `sql/07_tableau_extracts.sql`. Regenerate them after any change in `data/` or `sql/`.

| File | Rows | Columns | Used for |
|---|---|---|---|
| `kpi.csv` | 2 | `ab_group`, `users`, `paying_users`, `conversion_pct`, `arpu`, `arppu`, `avg_sessions`, `avg_time_min`, `avg_active_days`, `total_revenue` | KPI tiles |
| `tests.csv` | 11 | `metric_family`, `metric_order`, `metric`, `test`, `n_a`, `n_b`, `mean_a`, `mean_b`, `diff`, `lift_pct`, `ci_low`, `ci_high`, `ci_low_pct`, `ci_high_pct`, `z`, `p_value`, `p_holm`, `holm_verdict` | lift with 95% CI for every metric |
| `daily.csv` | 118 | `date`, `ab_group`, `day_number`, `revenue`, `dau`, `transactions`, `arpdau`, `cum_revenue`, `arpdau_7d` | daily ARPDAU and cumulative revenue |
| `active_days.csv` | 73 | `ab_group`, `active_days`, `users`, `share_pct`, `cum_share_pct` | the re-audit: who stops early |
| `percentiles.csv` | 10 | `ab_group`, `percentile`, `revenue` | revenue per paying user, p50 to p99 |
| `payers.csv` | 16,471 | `user_id`, `ab_group`, `total_revenue`, `total_transactions`, `active_days` | payer revenue histogram |
| `retention.csv` | 10 | `day`, `ab_group`, `retained`, `cohort`, `retention_pct` | retention by day since first activity in the window |

`lift_pct`, `ci_low_pct` and `ci_high_pct` are relative to group A. The relative CI is the absolute CI divided by the A mean, which ignores the variance of the denominator. For proportions `mean_a` and `mean_b` are in percent and `diff` in percentage points.

`retention.csv` keeps the notebook's anchor (first active day inside the window). See the re-audit in the main README for why it overstates the early drop.
