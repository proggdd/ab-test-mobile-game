-- Daily view: is the effect stable over the 59 days, and where is DAU heading?

CREATE OR REPLACE VIEW daily_trends AS
SELECT
    date,
    ab_group,
    date - min(date) OVER () + 1                                     AS day_number,
    revenue,
    users                                                            AS dau,
    transactions,
    arpdau,
    sum(revenue) OVER (PARTITION BY ab_group ORDER BY date)          AS cum_revenue,
    avg(arpdau)  OVER (PARTITION BY ab_group ORDER BY date
                       ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)     AS arpdau_7d
FROM daily;

-- B against A day by day.
CREATE OR REPLACE VIEW daily_lift AS
SELECT
    date,
    max(arpdau) FILTER (WHERE ab_group = 'A')                        AS arpdau_a,
    max(arpdau) FILTER (WHERE ab_group = 'B')                        AS arpdau_b,
    100 * (max(arpdau) FILTER (WHERE ab_group = 'B')
         / max(arpdau) FILTER (WHERE ab_group = 'A') - 1)            AS arpdau_lift_pct,
    max(cum_revenue) FILTER (WHERE ab_group = 'B')
      - max(cum_revenue) FILTER (WHERE ab_group = 'A')               AS cum_revenue_gap
FROM daily_trends
GROUP BY date;

-- DAU trend: least-squares slope in users per day.
CREATE OR REPLACE VIEW dau_trend AS
SELECT
    ab_group,
    regr_slope(dau, day_number)  AS dau_slope_per_day,
    min(dau)                     AS dau_min,
    max(dau)                     AS dau_max
FROM daily_trends
GROUP BY ab_group;

SELECT count(*)                                         AS days,
       count(*) FILTER (WHERE arpdau_lift_pct > 0)      AS days_b_ahead,
       round(min(arpdau_lift_pct)::numeric(20, 6), 2)   AS min_lift_pct,
       round(max(arpdau_lift_pct)::numeric(20, 6), 2)   AS max_lift_pct,
       round(max(cum_revenue_gap)::numeric(20, 6), 2)   AS revenue_gap_end
FROM daily_lift;

SELECT ab_group,
       round(dau_slope_per_day::numeric(20, 6), 2) AS dau_slope_per_day,
       dau_min, dau_max
FROM dau_trend
ORDER BY ab_group;
