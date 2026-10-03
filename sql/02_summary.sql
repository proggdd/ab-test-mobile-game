-- Group summary and the sample ratio mismatch check.

CREATE OR REPLACE VIEW summary AS
SELECT
    ab_group,
    count(*)                                              AS users,
    count(*) FILTER (WHERE is_payer)                      AS paying_users,
    100.0 * count(*) FILTER (WHERE is_payer) / count(*)   AS conversion_pct,
    avg(total_revenue)                                    AS arpu,
    avg(total_revenue) FILTER (WHERE is_payer)            AS arppu,
    avg(total_sessions::float8)                           AS avg_sessions,
    avg(total_time)                                       AS avg_time_min,
    avg(active_days::float8)                              AS avg_active_days,
    avg(total_transactions::float8)                       AS avg_transactions,
    sum(total_revenue)                                    AS total_revenue
FROM user_level
GROUP BY ab_group;

-- SRM: chi-square on group sizes against a 50/50 split, 1 degree of freedom.
-- p for chi-square(1) equals the two-sided normal tail at sqrt(chi2).
CREATE OR REPLACE VIEW srm_check AS
WITH sizes AS (
    SELECT count(*) FILTER (WHERE ab_group = 'A')::float8 AS n_a,
           count(*) FILTER (WHERE ab_group = 'B')::float8 AS n_b
    FROM user_level
),
chi AS (
    SELECT n_a, n_b,
           (power(n_a - (n_a + n_b) / 2, 2) + power(n_b - (n_a + n_b) / 2, 2))
               / ((n_a + n_b) / 2) AS chi2
    FROM sizes
),
tail AS (
    SELECT *, 1 / (1 + 0.2316419 * sqrt(chi2)) AS k FROM chi
)
SELECT n_a, n_b,
       100 * n_a / (n_a + n_b) AS share_a_pct,
       chi2,
       2 * exp(-chi2 / 2) / sqrt(2 * pi())
         * k * (0.319381530 + k * (-0.356563782 + k * (1.781477937
         + k * (-1.821255978 + k * 1.330274429)))) AS p_value
FROM tail;

SELECT ab_group, users, paying_users,
       round(conversion_pct::numeric(20, 6), 4)  AS conversion_pct,
       round(arpu::numeric(20, 6), 4)            AS arpu,
       round(arppu::numeric(20, 6), 4)           AS arppu,
       round(avg_sessions::numeric(20, 6), 2)    AS avg_sessions,
       round(avg_time_min::numeric(20, 6), 1)    AS avg_time_min,
       round(avg_active_days::numeric(20, 6), 2) AS avg_active_days
FROM summary
ORDER BY ab_group;

SELECT n_a, n_b, round(chi2::numeric(20, 6), 4) AS chi2, round(p_value::numeric(20, 6), 4) AS p_value
FROM srm_check;
