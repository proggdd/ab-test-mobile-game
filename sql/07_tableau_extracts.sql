-- Flat tables for the Tableau Public dashboard. run.py writes each tableau_*
-- view to tableau/<name>.csv. Long format where Tableau needs a group column.

CREATE OR REPLACE VIEW tableau_kpi AS
SELECT ab_group, users, paying_users, conversion_pct, arpu, arppu,
       avg_sessions, avg_time_min, avg_active_days, total_revenue
FROM summary;

CREATE OR REPLACE VIEW tableau_tests AS
SELECT
    CASE
        WHEN metric IN ('ARPU, $', 'ARPPU, $', 'Conversion to payer, %') THEN 'Revenue'
        WHEN metric LIKE '%retention%'                                   THEN 'Retention'
        ELSE 'Engagement'
    END                                                    AS metric_family,
    CASE metric
        WHEN 'ARPU, $'                THEN 1
        WHEN 'ARPPU, $'               THEN 2
        WHEN 'Conversion to payer, %' THEN 3
        WHEN 'Sessions per user'      THEN 4
        WHEN 'Time, min'              THEN 5
        WHEN 'Active days'            THEN 6
        WHEN 'D1 retention, %'        THEN 7
        WHEN 'D3 retention, %'        THEN 8
        WHEN 'D7 retention, %'        THEN 9
        WHEN 'D14 retention, %'       THEN 10
        WHEN 'D28 retention, %'       THEN 11
    END                                                    AS metric_order,
    metric, test, n_a, n_b, mean_a, mean_b, diff, lift_pct,
    ci_low, ci_high, ci_low_pct, ci_high_pct, z, p_value, p_holm,
    CASE WHEN p_holm < 0.05 THEN 'significant' ELSE 'not significant' END AS holm_verdict
FROM significance_tests;

CREATE OR REPLACE VIEW tableau_daily AS
SELECT date, ab_group, day_number, revenue, dau, transactions, arpdau,
       cum_revenue, arpdau_7d
FROM daily_trends;

-- Retention by day since first activity in the window (the notebook anchor).
CREATE OR REPLACE VIEW tableau_retention AS
SELECT day, 'A' AS ab_group, a_ret AS retained, a_n AS cohort, a_pct AS retention_pct
FROM retention_src
UNION ALL
SELECT day, 'B', b_ret, b_n, b_pct
FROM retention_src;

CREATE OR REPLACE VIEW tableau_active_days AS
SELECT ab_group, active_days, users, share_pct, cum_share_pct
FROM active_days_distribution;

CREATE OR REPLACE VIEW tableau_payers AS
SELECT user_id, ab_group, total_revenue, total_transactions, active_days
FROM user_level
WHERE is_payer;

CREATE OR REPLACE VIEW tableau_percentiles AS
SELECT ab_group, 50 AS percentile, p50 AS revenue FROM payer_percentiles
UNION ALL SELECT ab_group, 75, p75 FROM payer_percentiles
UNION ALL SELECT ab_group, 90, p90 FROM payer_percentiles
UNION ALL SELECT ab_group, 95, p95 FROM payer_percentiles
UNION ALL SELECT ab_group, 99, p99 FROM payer_percentiles;
