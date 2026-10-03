# A/B Test Analysis: Mobile Game Feature Rollout

Analysis of an A/B experiment in a mobile game. Test assignment for a game studio (studio not named, data anonymized). 59-day period, 100k users, two groups roughly 50/50. Goal: measure feature impact on revenue, engagement, retention, and recommend whether to ship B.

## TL;DR

Group B shows **+9.21% ARPU lift** versus control A. Statistically significant (Welch t-test p < 0.001; bootstrap CI $0.30 to $0.71 per user, i.e. +5.4% to +13.0% relative, 5000 iterations), stable across days and across the payer distribution.

The driver is ARPPU (+10.85%), not conversion. Existing payers spend more in B, but the test did not bring new payers in.

Early-day retention in B reads lower (D1 -1.42 pp, D3 -2.02 pp, D7 -1.37 pp, all p < 0.001), and my first readout took that as the feature pushing users out. **A later re-audit of my own analysis showed that reading was wrong.** The share of users who disengage is identical in both arms: 15.09% in A against 15.05% in B have 7 or fewer active days out of 59. B removes nobody. It makes the same-sized disengaging segment stop roughly one day sooner.

**Recommendation: ship B.** Revenue is up ~9% with no incremental churn, identical D14 and D28 retention, and rising DAU in both arms. Watch the early-disengagement cohort, but note what it is: users with 3-4 active days out of 59, the lowest-value segment in the dataset.

Full evidence and the reproduction script: [Re-audit](#re-audit-what-the-first-readout-got-wrong).

**[Interactive dashboard](https://proggdd.github.io/ab-test-mobile-game/)**: explore the full dataset with 5 charts (daily trends, distributions, retention curves, bootstrap confidence intervals) and accompanying data tables.

## Metrics

| Metric | A | B | Lift | p-value | Significant? |
|---|---|---|---|---|---|
| ARPU, $ | 5.45 | 5.95 | +9.21% | <0.001 | Yes |
| ARPPU, $ | 32.86 | 36.42 | +10.85% | <0.001 | Yes |
| Conversion to payer, % | 16.59 | 16.35 | -1.48% | 0.29 | No |
| Sessions per user | 34.1 | 36.4 | +6.75% | <0.001 | Yes |
| Time, min | 1089 | 1191 | +9.36% | <0.001 | Yes |
| Active days | 18.15 | 18.04 | -0.57% | 0.02 | No, after Holm correction p = 0.075 |
| **D1 retention, %** | **41.25** | **39.84** | **-3.43%** | **<0.001** | **Yes** |
| **D3 retention, %** | **36.55** | **34.52** | **-5.54%** | **<0.001** | **Yes** |
| **D7 retention, %** | **32.14** | **30.77** | **-4.26%** | **<0.001** | **Yes** |
| D14 retention, % | 29.74 | 29.66 | -0.28% | 0.78 | No |
| D28 retention, % | 29.63 | 29.62 | -0.00% | 1.00 | No |

Lift is relative throughout. Retention rows in percentage points: D1 -1.42, D3 -2.02, D7 -1.37, D14 -0.08, D28 0.00. The relative form makes a 1.4-point move read as 3.4%, which is worth stating explicitly in a ship-or-hold report. p-values are raw; across 11 comparisons only `Active days` changes status under Holm correction.

## Re-audit: what the first readout got wrong

The first version of this analysis recommended **against** shipping B, because early retention fell. That conclusion does not survive scrutiny, and the evidence against it was already in this repository.

**The metric was anchored on the wrong day.** `days_since_first` was computed from each user's first active day *inside the observation window*, not from install. The raw data carries `first_seen`; it is read in the first cell and then never used. For a user already active on day 1 of the window, "D1 retention" therefore means "was active on day 2": a measure of how activity is spaced, not of whether a cohort survives.

**The direct test contradicts the churn reading.** Whether users left needs no anchor at all: `active_days` per user sits in `data/user_level.csv`, which is committed here.

| Share of users | A | B | Difference |
|---|---|---|---|
| 3 or fewer active days | 4.660% | 8.952% | +4.29 pp |
| 5 or fewer | 12.291% | 14.516% | +2.23 pp |
| **7 or fewer** | **15.087%** | **15.051%** | **-0.04 pp** |
| 14 or fewer | 18.941% | 18.672% | -0.27 pp |

The cumulative shares converge by day 7. Band by band, the low-engagement users of A sit at 4-7 active days and those of B at 1-3:

| Active days | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| B minus A, pp | +0.52 | +1.93 | +1.85 | -0.17 | -1.90 | -1.52 | -0.74 |

The disengaging segment holds 7,528 users in A and 7,541 in B. Inside it, mean active days are 4.21 against 3.26: same people, about one day earlier.

Supporting evidence, all of it from files published here: mean active days -0.10 (-0.57%); no user in either arm has zero active days; D14 -0.08 pp (p = 0.78) and D28 0.000 pp (p = 1.00); DAU trends upward in both arms, slope +0.95 and +1.67 users per day over a 15,038-15,581 range.

**What it changes.** The feature does not push users out. It compresses the tail-off of a fixed-size, lowest-value segment by about a day while lifting revenue ~9% among the payers who stay. The original recommendation traded $26,279 of measured 59-day revenue against a churn cost that is not there.

Reproduce the check in one command, no raw file needed:

```bash
python analysis/reaudit_active_days.py
```


## How to run

```bash
pip install pandas numpy scipy statsmodels matplotlib jupyter
jupyter notebook notebook/ab_test_analysis.ipynb
```

Run cells in order. The notebook reads `data/ab_test_data.csv`. See `data/README.md` for the raw file (not committed, ~80 MB).

## SQL version

Every number above is recomputed in SQL from the committed CSV files: group summary, SRM, all 11 tests with 95% CIs and Holm correction, the active-days re-audit, payer revenue percentiles and daily trends. The queries are written for PostgreSQL and run unchanged in DuckDB.

```bash
pip install duckdb
python sql/run.py
```

`run.py` loads `data/*.csv`, runs `sql/02` to `sql/07`, compares the results with what the notebook saved (`output/summary_table.csv`, `data/retention.csv`, `docs/data.json`) and writes flat extracts for Tableau to `tableau/`. All 25 checks match. In PostgreSQL: `createdb abtest && psql -d abtest -f sql/run_postgres.psql`.

p-values in SQL come from the normal approximation (Abramowitz and Stegun 26.2.17). The smallest sample is about 8,000 payers per group, and the largest gap to scipy and statsmodels is under 1e-6.

Checks the notebook did not have:

| Check | A | B | Result |
|---|---|---|---|
| ARPU with revenue capped at the pooled p99 ($79.53) | 5.27 | 5.68 | +7.83%, z = 4.32: the lift does not come from the tail |
| Share of payer revenue from the top 1% of payers | 4.23% | 3.96% | B depends on its biggest spenders slightly less |
| Days on which ARPDAU in B is above A | | | 46 of 59 |

`sql/01_raw_to_marts.sql` rebuilds `user_level.csv`, `daily.csv` and `retention.csv` from the raw user-day file and reconciles them row by row with the notebook output. It also holds the install-anchored retention from the list below. It needs the raw file, so its numbers are not in this README yet; the logic is tested on a synthetic file with the same schema in both PostgreSQL and DuckDB.

## Repo layout

```
.
├── README.md
├── data/
│   ├── ab_test_data.csv (1.8M user-day rows, ~80 MB, not committed)
│   ├── user_level.csv (user-level aggregation)
│   ├── daily.csv (per day per group)
│   └── retention.csv (D1, D3, D7, D14, D28)
├── notebook/
│   └── ab_test_analysis.ipynb
├── sql/
│   ├── 00_schema.sql ... 07_tableau_extracts.sql
│   ├── run.py (DuckDB runner with checks against the notebook)
│   └── run_postgres.psql
├── tableau/ (flat extracts for the Tableau dashboard)
└── output/
    ├── 01_arpdau_daily.png
    ├── 02_cumulative_revenue.png
    ├── 03_arppu_distribution.png
    ├── 04_metrics_compare.png
    ├── 05_bootstrap_arpu_diff.png
    └── 06_retention_curve.png
```

## Approach in a nutshell

Unit of analysis is the user, not user-day. The split happens by `user_id`, and observations from the same user are correlated over days. Running a t-test on 1.8M user-day rows would yield artificially low p-values and false positives. I aggregate `groupby user_id` and run all tests at the user level.

Statistical tests:
- ARPU and engagement: Welch t-test plus bootstrap (5000 iterations) for robustness against the skewed revenue distribution
- Conversion to payer: two-proportion z-test
- Retention by cohort day: two-proportion z-test per day
- Mann-Whitney as a cross-check, but on ARPU it is insensitive because the median is 0 in both groups (5/6 users do not pay), so the right-tail shift is invisible to it. I trust Welch plus bootstrap for the revenue metric.

Sanity checks:
- SRM via chi-square on group sizes, p = 0.51, ok
- Each user is strictly in one group
- No missing values
- ARPDAU and cumulative revenue plotted per day, the effect is stable
- Percentiles of revenue per paying user shift across p50, p75, p90, p95, so the lift is systemic and not driven by a few whales

## What I would do with more time

- Recompute the retention curve from `first_seen` rather than from the first active day in the window, and treat users who install mid-experiment as censored instead of counting them in the denominator. The re-audit above settles the churn question without this, but the curve itself is still built on the wrong anchor. The query is ready (`retention_install` in `sql/01_raw_to_marts.sql`) and waits for the raw file
- CUPED with pre-period revenue as a covariate to narrow the ARPU CI
- Daily SRM check, not just the final one

These would be done before a final ship decision in a real project.

## Note on process

Much of the code and write-up was done in pair with Claude (Anthropic) as a pair-programmer. Architecture, metric selection, interpretation, and the validity check of every step stayed with me. AI tooling is a standard part of my workflow, it speeds up scaffolding and helps not miss obvious issues. The final calls are mine, including the one I later had to reverse: my first readout treated the early-retention drop as churn, and the re-audit above shows it is not. Finding that in my own work matters more to me than having been right the first time.

## Disclaimer

Data is anonymized and published as a portfolio case with the studio's permission. The studio, the game and the feature are not named. The dataset structure and metrics are kept untouched so the analysis is reproducible by any reader.

---

Author: Daniil Glotov
Email: gddviet@gmail.com
Telegram: @glotov_daniil
