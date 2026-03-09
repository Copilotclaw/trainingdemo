#!/usr/bin/env python3
"""
quota-tracker-compute.py — Compute burn rate and alert if needed.

Called by quota-tracker.sh after appending a new data point.
Reads state/quota-history.json and posts to #11 if exhaustion is projected within ALERT_DAYS.

Usage:
    python3 quota-tracker-compute.py <history_json> <alert_days> <repo>
"""
import json, sys, subprocess, os

def main():
    if len(sys.argv) < 4:
        print("usage: quota-tracker-compute.py <history_json> <alert_days> <repo>")
        sys.exit(1)

    history_file = sys.argv[1]
    alert_days = int(sys.argv[2])
    repo = sys.argv[3]

    if not os.path.exists(history_file):
        print("quota-tracker: no history file yet")
        return

    with open(history_file) as f:
        data = json.load(f)

    if len(data) < 4:
        print(f"quota-tracker: not enough data points yet ({len(data)}/4 needed)")
        return

    last = data[-1]
    limit = last["limit"]
    used = last["used"]
    remaining = limit - used

    # Find reference point 6h+ ago
    ref = None
    for point in reversed(data[:-1]):
        age_h = (last["epoch"] - point["epoch"]) / 3600
        if age_h >= 6:
            ref = point
            break

    if ref is None:
        print("quota-tracker: need 6h of history for burn rate — accumulating")
        return

    age_h = (last["epoch"] - ref["epoch"]) / 3600
    delta = last["used"] - ref["used"]

    if delta <= 0:
        print(f"quota-tracker: no new consumption in {age_h:.1f}h — burn rate ~0")
        return

    daily_rate = delta * 24 / age_h
    days_left = remaining / daily_rate if daily_rate > 0 else 999

    pct = used * 100 // limit if limit > 0 else 0
    print(f"quota-tracker: ~{daily_rate:.0f}/day ({delta} calls in {age_h:.1f}h) | {used}/{limit} ({pct}%) | ~{days_left:.1f} days left")

    if days_left <= alert_days:
        alert_msg = (
            f"quota burn alert: at current rate (~{daily_rate:.0f} calls/day), "
            f"will exhaust {limit} quota in ~{days_left:.1f} days. "
            f"Currently at {used}/{limit} ({pct}%). Month resets on the 1st."
        )
        print("quota-tracker: ALERT — posting to #11")
        result = subprocess.run(
            ["gh", "issue", "comment", "11", "--repo", repo, "--body", alert_msg],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            print("quota-tracker: alert posted to #11")
        else:
            print(f"quota-tracker: alert post failed: {result.stderr.strip()}")

if __name__ == "__main__":
    main()
