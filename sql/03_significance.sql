-- All 11 comparisons from the README in one query: Welch t-tests on per-user
-- means, z-tests on proportions, 95% CI on the B - A difference and Holm
-- correction across the family.
--
-- p-values use the normal approximation (Abramowitz and Stegun 26.2.17, error
-- below 1e-7). The smallest Welch sample is the payers, about 8,000 per group,
-- so the t distribution is normal for any practical purpose.

CREATE OR REPLACE VIEW significance_tests AS
WITH per_user AS (
    SELECT 'ARPU, $' AS metric, ab_group, total_revenue AS value FROM user_level
    UNION ALL
    SELECT 'ARPPU, $', ab_group, total_revenue FROM user_level WHERE is_payer
    UNION ALL
    SELECT 'Sessions per user', ab_group, total_sessions::float8 FROM user_level
    UNION ALL
    SELECT 'Time, min', ab_group, total_time FROM user_level
    UNION ALL
    SELECT 'Active days', ab_group, active_days::float8 FROM user_level
),
moments AS (
    SELECT metric,
           count(*) FILTER (WHERE ab_group = 'A')::float8  AS n_a,
           count(*) FILTER (WHERE ab_group = 'B')::float8  AS n_b,
           avg(value) FILTER (WHERE ab_group = 'A')        AS mean_a,
           avg(value) FILTER (WHERE ab_group = 'B')        AS mean_b,
           var_samp(value) FILTER (WHERE ab_group = 'A')   AS var_a,
           var_samp(value) FILTER (WHERE ab_group = 'B')   AS var_b
    FROM per_user
    GROUP BY metric
),
welch AS (
    SELECT metric, 'Welch t-test' AS test, n_a, n_b, mean_a, mean_b,
           sqrt(var_a / n_a + var_b / n_b) AS se_ci,
           sqrt(var_a / n_a + var_b / n_b) AS se_test
    FROM moments
),
proportions AS (
    SELECT 'Conversion to payer, %' AS metric,
           count(*) FILTER (WHERE ab_group = 'A')::float8              AS n_a,
           count(*) FILTER (WHERE ab_group = 'B')::float8              AS n_b,
           count(*) FILTER (WHERE ab_group = 'A' AND is_payer)::float8 AS x_a,
           count(*) FILTER (WHERE ab_group = 'B' AND is_payer)::float8 AS x_b
    FROM user_level
    UNION ALL
    SELECT 'D' || CAST(day AS TEXT) || ' retention, %',
           a_n::float8, b_n::float8, a_ret::float8, b_ret::float8
    FROM retention_src
),
ztest AS (
    -- CI on the unpooled standard error, test on the pooled one,
    -- as statsmodels proportions_ztest does
    SELECT metric, 'z-test for proportions' AS test, n_a, n_b,
           100 * x_a / n_a AS mean_a,
           100 * x_b / n_b AS mean_b,
           100 * sqrt((x_a / n_a) * (1 - x_a / n_a) / n_a
                    + (x_b / n_b) * (1 - x_b / n_b) / n_b) AS se_ci,
           100 * sqrt(((x_a + x_b) / (n_a + n_b)) * (1 - (x_a + x_b) / (n_a + n_b))
                    * (1 / n_a + 1 / n_b)) AS se_test
    FROM proportions
),
tests AS (
    SELECT * FROM welch
    UNION ALL
    SELECT * FROM ztest
),
stat AS (
    SELECT *,
           mean_b - mean_a AS diff,
           (mean_b - mean_a) / se_test AS z,
           1 / (1 + 0.2316419 * abs((mean_b - mean_a) / se_test)) AS k
    FROM tests
),
pval AS (
    SELECT *,
           2 * exp(-z * z / 2) / sqrt(2 * pi())
             * k * (0.319381530 + k * (-0.356563782 + k * (1.781477937
             + k * (-1.821255978 + k * 1.330274429)))) AS p_value
    FROM stat
),
ranked AS (
    SELECT *,
           row_number() OVER (ORDER BY p_value, metric) AS p_rank,
           count(*) OVER () AS m
    FROM pval
)
SELECT
    metric,
    test,
    n_a,
    n_b,
    mean_a,
    mean_b,
    diff,
    100 * diff / mean_a                        AS lift_pct,
    diff - 1.96 * se_ci                        AS ci_low,
    diff + 1.96 * se_ci                        AS ci_high,
    100 * (diff - 1.96 * se_ci) / mean_a       AS ci_low_pct,
    100 * (diff + 1.96 * se_ci) / mean_a       AS ci_high_pct,
    z,
    p_value,
    -- Holm: running max of (m - rank + 1) * p over the sorted p-values, capped at 1
    least(1.0, max((m - p_rank + 1) * p_value)
                   OVER (ORDER BY p_rank ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)) AS p_holm
FROM ranked;

SELECT metric,
       round(mean_a::numeric(20, 6), 2)   AS a,
       round(mean_b::numeric(20, 6), 2)   AS b,
       round(lift_pct::numeric(20, 6), 2) AS lift_pct,
       round(ci_low::numeric(20, 6), 4)   AS ci_low,
       round(ci_high::numeric(20, 6), 4)  AS ci_high,
       round(z::numeric(20, 6), 3)        AS z,
       round(p_value::numeric(20, 6), 4)  AS p,
       round(p_holm::numeric(20, 6), 4)   AS p_holm
FROM significance_tests
ORDER BY p_value, metric;
