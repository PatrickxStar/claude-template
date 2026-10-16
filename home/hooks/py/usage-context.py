#!/usr/bin/env python3
# usage-context.py - Python twin of usage-context.ps1 (same stdin JSON in, same stdout JSON out).
# SessionStart + UserPromptSubmit hook (same script wired to both events).
# Reads <work root>/system/usage-state.json and injects one plain usage line so every
# new prompt/session opens with current budget numbers in view. The work-queue skill
# refreshes that file from the get_usage tool at the start of each run.
# Missing or broken file -> print nothing (never guesses, never blocks).
# Standard library only. ASCII only. The constants below are swapped by the tests: keep
# them as one r'...' literal per line (raw, so a Windows path with backslashes survives).
#
# usage-state.json contract (ASCII, written as JSON):
# {
#   "checkedAt": "2026-01-01T09:00:00",   when the numbers were read
#   "fiveHourPct": 12, "weeklyAllPct": 30,
#   "capModel": "<model name>",           optional: a model you ration per day
#   "weeklyModelPct": 20, "modelTodayPct": 5, "modelDailyCapPct": 20, "modelCapHit": false
# }

import datetime
import json
import os
import sys

USAGE_FILE = r'__WORK_ROOT__/system/usage-state.json'


def emit(obj):
    sys.stdout.write(json.dumps(obj, separators=(',', ':')))
    sys.stdout.flush()


def num(v):
    # print 12.0 as 12, the way PowerShell does
    if v is None:
        return ''
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v)


def parse_when(s):
    s = str(s).strip()
    if s.endswith('Z'):
        s = s[:-1] + '+00:00'
    dt = datetime.datetime.fromisoformat(s)
    if dt.tzinfo is not None:
        dt = dt.astimezone().replace(tzinfo=None)
    return dt


def main():
    data = None
    try:
        data = json.loads(sys.stdin.buffer.read().decode('utf-8'))
    except Exception:
        data = None

    event_name = 'UserPromptSubmit'
    if isinstance(data, dict) and data.get('hook_event_name'):
        event_name = str(data['hook_event_name'])

    try:
        if not os.path.isfile(USAGE_FILE):
            return 0
        with open(USAGE_FILE, 'r', encoding='utf-8-sig') as fh:
            usage = json.loads(fh.read())
        if not isinstance(usage, dict):
            return 0

        # checkedAt is typed in by whichever session refreshed the file, and it can be wrong.
        # The file's own save time cannot lie, so age comes from whichever of the two is OLDER.
        checked_at = parse_when(usage.get('checkedAt'))
        saved_at = datetime.datetime.fromtimestamp(os.path.getmtime(USAGE_FILE))
        now = datetime.datetime.now()
        reading_at = checked_at
        if checked_at > saved_at + datetime.timedelta(minutes=10):
            reading_at = saved_at
        stale_min = int(round((now - reading_at).total_seconds() / 60.0))
        if stale_min < 0:
            stale_min = 0
        time_str = reading_at.strftime('%H:%M')

        line = 'Usage (as of %s, %d min ago): 5-hour %s%%, week-all %s%%.' % (
            time_str, stale_min, num(usage.get('fiveHourPct')), num(usage.get('weeklyAllPct')))
        cap_model = str(usage.get('capModel') or '')
        if cap_model:
            line += ' %s: week %s%%, today %s%% of %s%% cap.' % (
                cap_model, num(usage.get('weeklyModelPct')), num(usage.get('modelTodayPct')), num(usage.get('modelDailyCapPct')))
        if stale_min > 60:
            line = ('USAGE IS STALE (%s h old) - refresh usage-state.json with get_usage before trusting it. '
                    % num(round(stale_min / 60.0, 1))) + line
        cap_hit = usage.get('modelCapHit')
        if cap_hit is True or str(cap_hit).lower() == 'true':
            line = 'DAILY CAP HIT for %s - %s Say so in one line and use another model for the rest of today.' % (cap_model, line)

        emit({'hookSpecificOutput': {'hookEventName': event_name, 'additionalContext': line}})
        return 0
    except Exception:
        return 0


if __name__ == '__main__':
    sys.exit(main())
