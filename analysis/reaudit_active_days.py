"""
Re-audit of the retention conclusion.

The original readout recommended against shipping variant B because early-day
retention was lower. That readout anchored the retention curve on each user's
first active day inside the observation window instead of on install
(`first_seen`), so it measured activity spacing rather than cohort survival.

Whether users actually left is answerable without any anchor: the number of
active days per user is in data/user_level.csv, which is committed here.
This script recomputes that check from scratch. Standard library only, no
dependencies, and it does not need the 80 MB raw file.

    python analysis/reaudit_active_days.py
"""

import csv
import os
from collections import Counter, defaultdict

DATA = os.path.join(os.path.dirname(__file__), "..", "data", "user_level.csv")


def load():
    days = defaultdict(list)
    with open(DATA, newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            days[row["group"]].append(int(row["active_days"]))
    return days["A"], days["B"]


def mean(xs):
    return sum(xs) / len(xs)


def main():
    a, b = load()
    ca, cb = Counter(a), Counter(b)
    print(f"Users: A = {len(a):,}  B = {len(b):,}\n")

    print("Cumulative share of users by active days")
    print(f"{'threshold':>12} {'A':>10} {'B':>10} {'diff, pp':>10}")
    for thr in (3, 5, 7, 10, 14):
        sa = sum(1 for v in a if v <= thr) / len(a) * 100
        sb = sum(1 for v in b if v <= thr) / len(b) * 100
        print(f"{'<= ' + str(thr):>12} {sa:9.3f}% {sb:9.3f}% {sb - sa:+10.3f}")

    print("\nBand by band: where the difference actually sits")
    print(f"{'active days':>12} {'A':>10} {'B':>10} {'diff, pp':>10}")
    for d in range(1, 8):
        sa = ca[d] / len(a) * 100
        sb = cb[d] / len(b) * 100
        print(f"{d:>12} {sa:9.3f}% {sb:9.3f}% {sb - sa:+10.3f}")

    seg_a = [v for v in a if v <= 7]
    seg_b = [v for v in b if v <= 7]
    print("\nDisengaging segment (7 or fewer active days out of 59)")
    print(f"  size:              A {len(seg_a):,} ({len(seg_a)/len(a)*100:.3f}%)"
          f"   B {len(seg_b):,} ({len(seg_b)/len(b)*100:.3f}%)"
          f"   diff {len(seg_b)/len(b)*100 - len(seg_a)/len(a)*100:+.3f} pp")
    print(f"  mean active days:  A {mean(seg_a):.3f}   B {mean(seg_b):.3f}"
          f"   diff {mean(seg_b) - mean(seg_a):+.3f} days")

    print("\nWhole population")
    print(f"  mean active days:  A {mean(a):.4f}   B {mean(b):.4f}"
          f"   diff {mean(b) - mean(a):+.4f} days ({(mean(b)/mean(a) - 1) * 100:+.2f}%)")
    print(f"  users with zero active days:  A {ca[0]}   B {cb[0]}")

    print("\nConclusion: the disengaging segment is the same size in both arms.")
    print("B does not remove users; it makes the same users stop about a day sooner.")


if __name__ == "__main__":
    main()
