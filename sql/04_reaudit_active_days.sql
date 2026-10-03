-- The re-audit in SQL: did B push users out, or did the same users stop sooner?
-- active_days is a per-user total over the 59-day window, so no cohort anchor
-- is involved. Same numbers as analysis/reaudit_active_days.py.

CREATE OR REPLACE VIEW active_days_distribution AS
WITH counts AS (
    SELECT ab_group, active_days, count(*) AS users
    FROM user_level
    GROUP BY ab_group, active_days
)
SELECT
    ab_group,
    active_days,
    users,
    100.0 * users / sum(users) OVER (PARTITION BY ab_group)            AS share_pct,
    100.0 * sum(users) OVER (PARTITION BY ab_group ORDER BY active_days)
          / sum(users) OVER (PARTITION BY ab_group)                    AS cum_share_pct
FROM counts;

-- Cumulative share of users with at most N active days.
CREATE OR REPLACE VIEW reaudit_thresholds AS
WITH shares AS (
    SELECT
        t.max_days,
        100.0 * count(*) FILTER (WHERE u.ab_group = 'A' AND u.active_days <= t.max_days)
              / count(*) FILTER (WHERE u.ab_group = 'A') AS share_a_pct,
        100.0 * count(*) FILTER (WHERE u.ab_group = 'B' AND u.active_days <= t.max_days)
              / count(*) FILTER (WHERE u.ab_group = 'B') AS share_b_pct
    FROM (VALUES (3), (5), (7), (10), (14)) AS t(max_days)
    CROSS JOIN user_level u
    GROUP BY t.max_days
)
SELECT max_days, share_a_pct, share_b_pct, share_b_pct - share_a_pct AS diff_pp
FROM shares;

-- Band by band for 1..7 active days: where the difference sits.
CREATE OR REPLACE VIEW reaudit_bands AS
SELECT
    active_days,
    max(share_pct) FILTER (WHERE ab_group = 'A')            AS share_a_pct,
    max(share_pct) FILTER (WHERE ab_group = 'B')            AS share_b_pct,
    max(share_pct) FILTER (WHERE ab_group = 'B')
      - max(share_pct) FILTER (WHERE ab_group = 'A')        AS diff_pp
FROM active_days_distribution
WHERE active_days <= 7
GROUP BY active_days;

-- The disengaging segment: size and how long it stays.
CREATE OR REPLACE VIEW reaudit_segment AS
SELECT
    ab_group,
    count(*)                                    AS users_7_or_fewer_days,
    avg(active_days::float8)                    AS mean_active_days,
    100.0 * count(*) / max(g.group_size)        AS share_pct
FROM user_level u
JOIN (SELECT ab_group AS grp, count(*) AS group_size FROM user_level GROUP BY ab_group) g
  ON g.grp = u.ab_group
WHERE active_days <= 7
GROUP BY ab_group;

SELECT max_days,
       round(share_a_pct::numeric(20, 6), 3) AS a_pct,
       round(share_b_pct::numeric(20, 6), 3) AS b_pct,
       round(diff_pp::numeric(20, 6), 3)     AS diff_pp
FROM reaudit_thresholds
ORDER BY max_days;

SELECT active_days,
       round(share_a_pct::numeric(20, 6), 3) AS a_pct,
       round(share_b_pct::numeric(20, 6), 3) AS b_pct,
       round(diff_pp::numeric(20, 6), 3)     AS diff_pp
FROM reaudit_bands
ORDER BY active_days;

SELECT ab_group, users_7_or_fewer_days,
       round(mean_active_days::numeric(20, 6), 2) AS mean_active_days,
       round(share_pct::numeric(20, 6), 3)        AS share_pct
FROM reaudit_segment
ORDER BY ab_group;
