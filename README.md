# A/B Test Analysis: Mobile Game Feature Rollout

Analysis of an A/B experiment in a mobile game. Test assignment for a game studio (brand hidden under NDA, data anonymized). 59-day period, 100k users, two groups roughly 50/50. Goal: measure feature impact on revenue, engagement, retention, and recommend whether to ship B.

## TL;DR

Group B shows **+9.21% ARPU lift** versus control A. Statistically significant (Welch t-test p < 0.001, bootstrap CI [+0.30, +0.71], 5000 iterations), stable across days and across the payer distribution.

The driver is ARPPU (+10.85%), not conversion. Existing payers spend more in B, but the test did not bring new payers in.

**Retention in B is significantly lower on early days:** D1 -3.4%, D3 -5.5%, D7 -4.3% (all p < 0.001). By D14 the gap disappears. The feature monetizes users who stay, but pushes some users out earlier.

**Recommendation: do not ship B as is.** Investigate what in the feature drives the D1-D7 churn, build B2 with the early friction removed, run a fresh test. If shipping anyway is mandatory, monitor early retention closely and be ready to roll back.

**[Interactive dashboard](https://proggdd.github.io/ab-test-mobile-game/)** — explore the full dataset with 5 charts (daily trends, distributions, retention curves, bootstrap confidence intervals) and accompanying data tables.

## Metrics

| Metric | A | B | Lift | p-value | Significant? |
|---|---|---|---|---|---|
| ARPU, $ | 5.45 | 5.95 | +9.21% | <0.001 | Yes |
| ARPPU, $ | 32.86 | 36.42 | +10.85% | <0.001 | Yes |
| Conversion to payer, % | 16.59 | 16.35 | -1.48% | 0.29 | No |
| Sessions per user | 34.1 | 36.4 | +6.75% | <0.001 | Yes |
| Time, min | 1089 | 1191 | +9.36% | <0.001 | Yes |
| Active days | 18.15 | 18.04 | -0.57% | 0.02 | Borderline |
| **D1 retention, %** | **41.25** | **39.84** | **-3.43%** | **<0.001** | **Yes** |
| **D3 retention, %** | **36.55** | **34.52** | **-5.54%** | **<0.001** | **Yes** |
| **D7 retention, %** | **32.14** | **30.77** | **-4.26%** | **<0.001** | **Yes** |
| D14 retention, % | 29.74 | 29.66 | -0.28% | 0.78 | No |
| D28 retention, % | 29.63 | 29.62 | -0.00% | 1.00 | No |

## How to run

```bash
pip install pandas numpy scipy statsmodels matplotlib jupyter
jupyter notebook notebook/ab_test_analysis.ipynb
```

Run cells in order. The notebook reads `data/ab_test_data.csv`. See `data/README.md` for the raw file (not committed, ~80 MB).

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

- Segment effect by `first_seen` (new vs retained users). Hypothesis: the retention drop in B sits in new users, while retained users show a clean positive effect
- CUPED with pre-period revenue as a covariate to narrow the ARPU CI
- Daily SRM check, not just the final one
- Winsorize revenue at p99 and recompute, to confirm ARPU lift is not pulled by the tail

These would be done before a final ship decision in a real project.

## Note on process

Much of the code and write-up was done in pair with Claude (Anthropic) as a pair-programmer. Architecture, metric selection, interpretation, and the validity check of every step stayed with me. AI tooling is a standard part of my workflow, it speeds up scaffolding and helps not miss obvious issues. The final calls (for example, that shipping B as-is is risky because of the retention drop) are mine.

## Disclaimer

Data is anonymized and published as a portfolio case. Game name, studio name, and the feature itself are hidden under NDA. The dataset structure and metrics are kept untouched so the analysis is reproducible by any reader.

---

Author: Daniil Glotov
Email: gddviet@gmail.com
Telegram: @glotov_daniil
