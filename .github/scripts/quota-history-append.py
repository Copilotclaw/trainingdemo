#!/usr/bin/env python3
"""
quota-history-append.py — Append a quota snapshot to state/quota-history.json.

Usage:
    python3 quota-history-append.py <history_file> <ts> <epoch> <used> <limit>
"""
import json, sys, os

def main():
    if len(sys.argv) < 6:
        print("usage: quota-history-append.py <history_file> <ts> <epoch> <used> <limit>")
        sys.exit(1)

    history_file = sys.argv[1]
    ts = sys.argv[2]
    epoch = int(sys.argv[3])
    used = int(sys.argv[4])
    limit = int(sys.argv[5])

    os.makedirs(os.path.dirname(history_file), exist_ok=True)

    data = []
    if os.path.exists(history_file):
        with open(history_file) as f:
            try:
                data = json.load(f)
            except Exception:
                data = []

    data.append({"ts": ts, "epoch": epoch, "used": used, "limit": limit})
    data = data[-96:]  # keep last 96 points (~48h)

    with open(history_file, "w") as f:
        json.dump(data, f, indent=2)

    print(f"quota-tracker: appended point #{len(data)} | {used}/{limit} at {ts}")

if __name__ == "__main__":
    main()
