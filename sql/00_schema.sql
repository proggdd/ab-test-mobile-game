-- Tables for the committed CSV files in data/.
-- Dialect: PostgreSQL. The same statements run unchanged in DuckDB (see run.py).
-- "group" is a reserved word, so the column is called ab_group here.

CREATE TABLE user_level (
    user_id            INTEGER PRIMARY KEY,
    ab_group           TEXT    NOT NULL CHECK (ab_group IN ('A', 'B')),
    total_revenue      FLOAT8  NOT NULL CHECK (total_revenue >= 0),
    total_sessions     INTEGER NOT NULL,
    total_time         FLOAT8  NOT NULL,
    total_transactions INTEGER NOT NULL,
    active_days        INTEGER NOT NULL CHECK (active_days BETWEEN 1 AND 59),
    is_payer           BOOLEAN NOT NULL
);

CREATE TABLE daily (
    date         DATE    NOT NULL,
    ab_group     TEXT    NOT NULL CHECK (ab_group IN ('A', 'B')),
    revenue      FLOAT8  NOT NULL,
    users        INTEGER NOT NULL,
    transactions INTEGER NOT NULL,
    arpdau       FLOAT8  NOT NULL,
    PRIMARY KEY (date, ab_group)
);

-- retention.csv as the notebook wrote it: one row per cohort day,
-- counts of retained users and cohort sizes per group.
CREATE TABLE retention_src (
    day   INTEGER PRIMARY KEY,
    a_pct FLOAT8,
    b_pct FLOAT8,
    lift  FLOAT8,
    p     FLOAT8,
    a_ret INTEGER,
    a_n   INTEGER,
    b_ret INTEGER,
    b_n   INTEGER
);

-- Raw user-day table from the task assignment (data/ab_test_data.csv, ~80 MB,
-- not committed). Only needed for 01_raw_to_marts.sql.
CREATE TABLE raw_user_day (
    user_id      INTEGER NOT NULL,
    ab_group     TEXT    NOT NULL,
    date         DATE    NOT NULL,
    first_seen   DATE,
    revenue      FLOAT8  NOT NULL,
    sessions     INTEGER NOT NULL,
    time_played  FLOAT8  NOT NULL,
    transactions INTEGER NOT NULL
);
