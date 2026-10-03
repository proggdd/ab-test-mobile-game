-- Is the ARPPU lift systemic or driven by a few whales?

-- Revenue per paying user by percentile (linear interpolation, same as numpy).
CREATE OR REPLACE VIEW payer_percentiles AS
SELECT
    ab_group,
    count(*)                                                     AS payers,
    percentile_cont(0.50) WITHIN GROUP (ORDER BY total_revenue)  AS p50,
    percentile_cont(0.75) WITHIN GROUP (ORDER BY total_revenue)  AS p75,
    percentile_cont(0.90) WITHIN GROUP (ORDER BY total_revenue)  AS p90,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY total_revenue)  AS p95,
    percentile_cont(0.99) WITHIN GROUP (ORDER BY total_revenue)  AS p99,
    max(total_revenue)                                           AS max_revenue
FROM user_level
WHERE is_payer
GROUP BY ab_group;

-- Share of payer revenue that comes from the top 1% and top 10% of payers.
CREATE OR REPLACE VIEW payer_concentration AS
WITH ranked AS (
    SELECT ab_group, total_revenue,
           ntile(100) OVER (PARTITION BY ab_group ORDER BY total_revenue DESC) AS bucket
    FROM user_level
    WHERE is_payer
)
SELECT
    ab_group,
    sum(total_revenue)                                                       AS payer_revenue,
    100 * sum(total_revenue) FILTER (WHERE bucket = 1)   / sum(total_revenue) AS top1_share_pct,
    100 * sum(total_revenue) FILTER (WHERE bucket <= 10) / sum(total_revenue) AS top10_share_pct
FROM ranked
GROUP BY ab_group;

-- ARPU with revenue capped at the pooled p99 of all users. If the lift holds
-- here, the tail does not carry it.
CREATE OR REPLACE VIEW arpu_winsorized AS
WITH cap AS (
    SELECT percentile_cont(0.99) WITHIN GROUP (ORDER BY total_revenue) AS p99
    FROM user_level
),
capped AS (
    SELECT u.ab_group, least(u.total_revenue, c.p99) AS revenue
    FROM user_level u
    CROSS JOIN cap c
),
moments AS (
    SELECT
        count(*) FILTER (WHERE ab_group = 'A')::float8 AS n_a,
        count(*) FILTER (WHERE ab_group = 'B')::float8 AS n_b,
        avg(revenue) FILTER (WHERE ab_group = 'A')     AS arpu_a,
        avg(revenue) FILTER (WHERE ab_group = 'B')     AS arpu_b,
        var_samp(revenue) FILTER (WHERE ab_group = 'A') AS var_a,
        var_samp(revenue) FILTER (WHERE ab_group = 'B') AS var_b
    FROM capped
)
SELECT
    (SELECT p99 FROM cap)                                  AS cap_p99,
    arpu_a,
    arpu_b,
    100 * (arpu_b - arpu_a) / arpu_a                       AS lift_pct,
    (arpu_b - arpu_a) / sqrt(var_a / n_a + var_b / n_b)    AS z
FROM moments;

SELECT ab_group, payers,
       round(p50::numeric(20, 6), 2) AS p50,
       round(p75::numeric(20, 6), 2) AS p75,
       round(p90::numeric(20, 6), 2) AS p90,
       round(p95::numeric(20, 6), 2) AS p95,
       round(p99::numeric(20, 6), 2) AS p99
FROM payer_percentiles
ORDER BY ab_group;

SELECT ab_group,
       round(payer_revenue::numeric(20, 6), 2)   AS payer_revenue,
       round(top1_share_pct::numeric(20, 6), 2)  AS top1_share_pct,
       round(top10_share_pct::numeric(20, 6), 2) AS top10_share_pct
FROM payer_concentration
ORDER BY ab_group;

SELECT round(cap_p99::numeric(20, 6), 2)  AS cap_p99,
       round(arpu_a::numeric(20, 6), 4)   AS arpu_a,
       round(arpu_b::numeric(20, 6), 4)   AS arpu_b,
       round(lift_pct::numeric(20, 6), 2) AS lift_pct,
       round(z::numeric(20, 6), 2)        AS z
FROM arpu_winsorized;
