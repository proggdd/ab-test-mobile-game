-- Build the committed marts from the raw user-day file and check that SQL and
-- pandas agree. Needs raw_user_day loaded from data/ab_test_data.csv (not
-- committed, see data/README.md). Run: python sql/run.py --raw data/ab_test_data.csv

-- 1. Data quality on the raw table.
CREATE OR REPLACE VIEW raw_quality AS
SELECT
    count(*)                                         AS user_day_rows,
    count(DISTINCT user_id)                          AS users,
    min(date)                                        AS first_date,
    max(date)                                        AS last_date,
    (SELECT count(*) FROM (
        SELECT user_id FROM raw_user_day
        GROUP BY user_id HAVING count(DISTINCT ab_group) > 1) x) AS users_in_both_groups,
    (SELECT count(*) FROM (
        SELECT user_id, date FROM raw_user_day
        GROUP BY user_id, date HAVING count(*) > 1) x)          AS duplicate_user_days,
    count(*) FILTER (WHERE first_seen IS NULL)       AS rows_without_first_seen,
    count(*) FILTER (WHERE date < first_seen)        AS rows_before_first_seen,
    count(*) FILTER (WHERE revenue < 0)              AS negative_revenue_rows
FROM raw_user_day;

-- 2. User level: one row per user, the unit of analysis for every test.
CREATE OR REPLACE VIEW user_level_from_raw AS
SELECT
    user_id,
    ab_group,
    sum(revenue)          AS total_revenue,
    sum(sessions)         AS total_sessions,
    sum(time_played)      AS total_time,
    sum(transactions)     AS total_transactions,
    count(DISTINCT date)  AS active_days,
    sum(revenue) > 0      AS is_payer
FROM raw_user_day
GROUP BY user_id, ab_group;

-- 3. Daily per group.
CREATE OR REPLACE VIEW daily_from_raw AS
SELECT
    date,
    ab_group,
    sum(revenue)                              AS revenue,
    count(DISTINCT user_id)                   AS users,
    sum(transactions)                         AS transactions,
    sum(revenue) / count(DISTINCT user_id)    AS arpdau
FROM raw_user_day
GROUP BY date, ab_group;

-- 4. Retention as the notebook computed it: day n after the first active day
--    inside the window. This is the anchor the re-audit questions (README).
CREATE OR REPLACE VIEW retention_first_active AS
WITH first_active AS (
    SELECT user_id, ab_group, min(date) AS first_active
    FROM raw_user_day
    GROUP BY user_id, ab_group
),
horizons AS (
    SELECT n FROM (VALUES (1), (3), (7), (14), (28)) AS h(n)
),
returned AS (
    SELECT DISTINCT r.user_id, h.n
    FROM raw_user_day r
    JOIN first_active f ON f.user_id = r.user_id
    JOIN horizons h ON r.date - f.first_active = h.n
)
SELECT
    h.n                                                    AS day,
    f.ab_group,
    count(*)                                               AS cohort,
    count(ret.user_id)                                     AS retained,
    100.0 * count(ret.user_id) / count(*)                  AS retention_pct
FROM first_active f
CROSS JOIN horizons h
LEFT JOIN returned ret ON ret.user_id = f.user_id AND ret.n = h.n
GROUP BY h.n, f.ab_group;

-- 5. Retention from install (first_seen), the fix listed under
--    "What I would do with more time". Only users who installed inside the
--    window count, and day n must fit inside the window (right censoring).
CREATE OR REPLACE VIEW retention_install AS
WITH bounds AS (
    SELECT min(date) AS d0, max(date) AS d1 FROM raw_user_day
),
installs AS (
    SELECT user_id, ab_group, min(first_seen) AS install_date
    FROM raw_user_day
    GROUP BY user_id, ab_group
),
eligible AS (
    SELECT i.user_id, i.ab_group, h.n, i.install_date + h.n AS target_date
    FROM installs i
    CROSS JOIN (VALUES (1), (3), (7), (14), (28)) AS h(n)
    CROSS JOIN bounds b
    WHERE i.install_date >= b.d0
      AND i.install_date + h.n <= b.d1
),
hits AS (
    SELECT DISTINCT e.user_id, e.n
    FROM eligible e
    JOIN raw_user_day r ON r.user_id = e.user_id AND r.date = e.target_date
)
SELECT
    e.n                                         AS day,
    e.ab_group,
    count(*)                                    AS cohort,
    count(h.user_id)                            AS retained,
    100.0 * count(h.user_id) / count(*)         AS retention_pct
FROM eligible e
LEFT JOIN hits h ON h.user_id = e.user_id AND h.n = e.n
GROUP BY e.n, e.ab_group;

-- 6. Reconciliation: SQL marts against the CSV files the notebook wrote.
CREATE OR REPLACE VIEW check_marts AS
SELECT 'user_level' AS mart,
       (SELECT count(*) FROM user_level) AS rows_in_csv,
       count(*) AS rows_matched,
       count(*) FILTER (WHERE r.ab_group <> c.ab_group
                           OR abs(r.total_revenue - c.total_revenue) > 1e-6
                           OR r.total_sessions <> c.total_sessions
                           OR abs(r.total_time - c.total_time) > 1e-6
                           OR r.total_transactions <> c.total_transactions
                           OR r.active_days <> c.active_days
                           OR r.is_payer <> c.is_payer) AS mismatches
FROM user_level_from_raw r
JOIN user_level c ON c.user_id = r.user_id
UNION ALL
SELECT 'daily',
       (SELECT count(*) FROM daily),
       count(*),
       count(*) FILTER (WHERE abs(r.revenue - c.revenue) > 1e-6
                           OR r.users <> c.users
                           OR r.transactions <> c.transactions)
FROM daily_from_raw r
JOIN daily c ON c.date = r.date AND c.ab_group = r.ab_group
UNION ALL
SELECT 'retention',
       (SELECT 2 * count(*) FROM retention_src),
       count(*),
       count(*) FILTER (WHERE r.retained <> CASE r.ab_group WHEN 'A' THEN s.a_ret ELSE s.b_ret END
                           OR r.cohort   <> CASE r.ab_group WHEN 'A' THEN s.a_n   ELSE s.b_n   END)
FROM retention_first_active r
JOIN retention_src s ON s.day = r.day;

SELECT * FROM raw_quality;
SELECT * FROM check_marts;
SELECT day, ab_group, cohort, retained, round(retention_pct::numeric(20, 6), 2) AS retention_pct
FROM retention_install
ORDER BY day, ab_group;
