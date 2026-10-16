#!/usr/bin/env python3
# command-guard.py - Python twin of command-guard.ps1 (same stdin JSON in, same stdout JSON out).
# PreToolUse hook, matcher "Bash|PowerShell".
# Blocks: any command matching a line in config/forbidden-commands.txt, writing a
# system/*.json state file without ConvertTo-Json (a broken state file looks empty),
# and writing a draft/reply file from the shell (drafts go through the Write tool so
# voice-gate can read them). Any parse error allows silently (never blocks real work).
# Standard library only. ASCII only. The constants below are swapped by the tests: keep
# them as one r'...' literal per line (raw, so a Windows path with backslashes survives).

import json
import os
import re
import sys

WORK_ROOT = r'__WORK_ROOT__'
CONFIG_DIR = r'__CLAUDE_HOME__/hooks/config'
ITEM_NOUN = r'__ITEM__'


def emit(obj):
    sys.stdout.write(json.dumps(obj, separators=(',', ':')))
    sys.stdout.flush()


def norm(p):
    return str(p).replace('\\', '/')


def read_rules(path):
    # returns a list of (pattern, reason) from "<regex><TAB><reason>" lines
    rules = []
    if not os.path.isfile(path):
        return rules
    with open(path, 'r', encoding='utf-8-sig') as fh:
        for line in fh:
            line = line.rstrip('\r\n')
            t = line.strip()
            if t == '' or t.startswith('#'):
                continue
            parts = line.split('\t', 1)
            pat = parts[0].strip()
            if pat == '':
                continue
            why = 'blocked by forbidden-commands.txt'
            if len(parts) == 2 and parts[1].strip() != '':
                why = parts[1].strip()
            rules.append((pat, why))
    return rules


def main():
    try:
        data = json.loads(sys.stdin.buffer.read().decode('utf-8'))
    except Exception:
        return 0
    try:
        tool_input = data.get('tool_input')
        if not isinstance(tool_input, dict):
            return 0
        command = tool_input.get('command')
        if command is None or command == '':
            return 0
        command = str(command)

        reason = None

        # ---- 1. the forbidden list -------------------------------------------------
        for pat, why in read_rules(os.path.join(CONFIG_DIR, 'forbidden-commands.txt')):
            try:
                if re.search(pat, command, re.IGNORECASE):
                    reason = why
                    break
            except Exception:
                pass

        # ---- 2. state file written without serializing ------------------------------
        if reason is None:
            cmd_norm = norm(command)
            sys_esc = re.escape(norm(WORK_ROOT).rstrip('/') + '/system/')
            state_pat = r'(Set-Content|Out-File|Add-Content|>{1,2})[^|;\r\n]*' + sys_esc + r'[\w.-]+\.json'
            if re.search(state_pat, cmd_norm, re.IGNORECASE) and not re.search('ConvertTo-Json', command, re.IGNORECASE):
                reason = ('State file write without ConvertTo-Json - a broken state file looks like an empty one. '
                          'Serialize it or use a helper script.')

        # ---- 3. a draft written from the shell never meets voice-gate ---------------
        if reason is None:
            draft_name = (r'[^\s"\'|;<>]*\b(draft[-_][\w.-]*|reply-[\w.-]*|new-' + re.escape(ITEM_NOUN)
                          + r'[\w.-]*)\.txt\b')
            draft_write = ('('
                           + r'(Set-Content|Out-File|Add-Content)\s+(-(Path|LiteralPath|FilePath)\s+)?["\']?' + draft_name + '|'
                           + r'(WriteAllText|WriteAllLines)\s*\(\s*["\']?' + draft_name + '|'
                           + r'(>{1,2}|\btee\b(\s+-a)?)\s*["\']?' + draft_name + '|'
                           + r'\bsed\s+-i[^|;\r\n]*' + draft_name + ')')
            if re.search(draft_write, command, re.IGNORECASE):
                reason = 'Draft files are written with the Write tool, not from the shell, so the voice gate can check them.'

        if reason:
            emit({'hookSpecificOutput': {
                'hookEventName': 'PreToolUse',
                'permissionDecision': 'deny',
                'permissionDecisionReason': reason}})
        return 0
    except Exception:
        return 0


if __name__ == '__main__':
    sys.exit(main())
