#!/usr/bin/env python3
# disk-gate.py - Python twin of disk-gate.ps1 (same stdin JSON in, same stdout JSON out).
# One script, three events (work must reach disk, never only a transcript):
#   PostToolUse  (matcher "Write|Edit")  - tracker: remember which work-item folders
#                                          this session / subagent wrote into.
#   Stop                                 - main session may not stop while a touched or
#                                          mentioned item folder lacks findings.md + a
#                                          parseable summary.json.
#   SubagentStop (matcher "planner|runner|writer")
#                                        - a chain agent may not return without its artifact.
# At most 2 blocks per session/agent, then it allows and tells you what was left undone.
# Any parse error allows silently (never blocks real work).
# Standard library only. ASCII only. The constants below are swapped by the tests: keep
# them as one r'...' literal per line (raw, so a Windows path with backslashes survives).

import datetime
import json
import os
import re
import sys
import time

WORK_ROOT = r'__WORK_ROOT__'
STATE_DIR = r'__CLAUDE_HOME__/hooks/state'
LOG_FILE = r'__CLAUDE_HOME__/hooks/logs/disk-gate.log'
ITEM_NOUN = r'__ITEM__'
RESERVED = ['system', 'reports', 'archive', 'adhoc']
MAX_BLOCKS = 2


def emit(obj):
    sys.stdout.write(json.dumps(obj, separators=(',', ':')))
    sys.stdout.flush()


def norm(p):
    return str(p).replace('\\', '/')


def gate_log(msg):
    try:
        d = os.path.dirname(LOG_FILE)
        if d and not os.path.isdir(d):
            os.makedirs(d, exist_ok=True)
        if os.path.isfile(LOG_FILE) and os.path.getsize(LOG_FILE) > 1024 * 1024:
            os.replace(LOG_FILE, LOG_FILE + '.old')
        with open(LOG_FILE, 'a', encoding='utf-8') as fh:
            fh.write(datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S') + ' ' + msg + '\n')
    except Exception:
        pass


def item_path(leaf):
    return os.path.join(WORK_ROOT, leaf)


def root_escaped():
    return re.escape(norm(WORK_ROOT).rstrip('/'))


def get_item_folder(path):
    # The item folder (full path) a file path lives in, or None.
    # An item folder is any direct child of the work root that is not a reserved name.
    if not path:
        return None
    m = re.match('^' + root_escaped() + r'/([^/]+)/', norm(path), re.IGNORECASE)
    if not m:
        return None
    leaf = m.group(1)
    if leaf.lower() in RESERVED:
        return None
    return item_path(leaf)


def get_folder_issues(folder, lenient=False):
    # lenient (an item only MENTIONED, not written to): the folder just has to exist on disk
    # with findings.md or summary.json, so a briefing that lists stubs is not forced to work them.
    issues = []
    if not os.path.isdir(folder):
        leaf = os.path.basename(folder.rstrip('\\/'))
        archived = os.path.join(WORK_ROOT, 'archive', leaf)
        if os.path.isdir(archived):
            folder = archived
        else:
            return [folder + ' does not exist (no findings.md, no summary.json)']
    findings = os.path.join(folder, 'findings.md')
    summary = os.path.join(folder, 'summary.json')
    if lenient:
        if os.path.isfile(findings) or os.path.isfile(summary):
            return []
        return [folder + ' has neither findings.md nor summary.json']
    if not os.path.isfile(findings):
        issues.append(findings + ' is missing')
    if not os.path.isfile(summary):
        issues.append(summary + ' is missing')
    else:
        try:
            with open(summary, 'r', encoding='utf-8-sig') as fh:
                json.loads(fh.read())
        except Exception:
            issues.append(summary + ' does not parse as JSON')
    return issues


def unique(seq):
    out = []
    for x in seq:
        if x not in out:
            out.append(x)
    return out


def noun_mentions(msg):
    # A mention = "<item noun> <number>" (e.g. "ticket 12345", "ticket #12345"). A bare "#12345"
    # is NOT a mention: pull request and issue numbers look the same and blocked a session once.
    pat = r'\b' + re.escape(ITEM_NOUN) + r'\s*#?\s*(\d{3,8})\b'
    return [item_path(m.group(1)) for m in re.finditer(pat, msg, re.IGNORECASE)]


def path_mentions(msg):
    # an explicit "<work root>/<id>" path, either separator
    pat = root_escaped() + r'/([^/\s"\')`]+)'
    out = []
    for m in re.finditer(pat, norm(msg), re.IGNORECASE):
        leaf = m.group(1)
        if leaf.lower() in RESERVED:
            continue
        out.append(item_path(leaf))
    return out


def main():
    try:
        data = json.loads(sys.stdin.buffer.read().decode('utf-8'))
    except Exception:
        return 0
    try:
        event_name = str(data.get('hook_event_name') or '')
        sid = re.sub(r'[^\w-]', '', str(data.get('session_id') or ''))
        if sid == '':
            return 0

        os.makedirs(STATE_DIR, exist_ok=True)
        cutoff = time.time() - 3 * 24 * 3600
        for name in os.listdir(STATE_DIR):
            if name.startswith('disk-gate-'):
                p = os.path.join(STATE_DIR, name)
                try:
                    if os.path.getmtime(p) < cutoff:
                        os.remove(p)
                except Exception:
                    pass

        # Plain tab-separated lines, not JSON (same files the PowerShell twin writes).
        touch_file = os.path.join(STATE_DIR, 'disk-gate-' + sid + '.touched')   # agentKey<TAB>folder
        block_file = os.path.join(STATE_DIR, 'disk-gate-' + sid + '.blocks')    # agentKey<TAB>count

        agent_key = 'main'
        if data.get('agent_id'):
            agent_key = str(data['agent_id'])

        def read_lines(path):
            if not os.path.isfile(path):
                return []
            with open(path, 'r', encoding='utf-8-sig') as fh:
                return [l.rstrip('\r\n') for l in fh]

        def get_touched(key):
            out = []
            for l in read_lines(touch_file):
                parts = l.split('\t', 1)
                if len(parts) == 2 and parts[0] == key:
                    out.append(parts[1])
            return unique(out)

        def get_block_count(key):
            n = 0
            for l in read_lines(block_file):
                parts = l.split('\t', 1)
                if len(parts) == 2 and parts[0] == key:
                    try:
                        n = int(parts[1])
                    except Exception:
                        n = 0
            return n

        def set_block_count(key, n):
            keep = [l for l in read_lines(block_file) if l.split('\t', 1)[0] != key]
            keep.append(key + '\t' + str(n))
            with open(block_file, 'w', encoding='utf-8') as fh:
                fh.write('\n'.join(keep) + '\n')

        def send_verdict(key, issues, label, event_for_msg):
            n = get_block_count(key)
            listed = '; '.join(issues)
            if n < MAX_BLOCKS:
                set_block_count(key, n + 1)
                gate_log('BLOCK %s %s (%d/%d): %s' % (event_for_msg, label, n + 1, MAX_BLOCKS, listed))
                hint = 'Write the missing file(s) now, then finish.'
                if event_for_msg == 'Stop':
                    hint += ' If this truly needs no folder (pure lookup, no diagnosis), say [no-work-folder] and why in your reply.'
                else:
                    hint += ' The next agent in the chain reads only what is on disk.'
                emit({'decision': 'block', 'reason': 'disk-gate: ' + listed + '. ' + hint})
            else:
                set_block_count(key, 0)
                gate_log('GAVE-UP %s %s after %d blocks: %s' % (event_for_msg, label, MAX_BLOCKS, listed))
                emit({'systemMessage': 'disk-gate: %s stopped with work not on disk after %d reminders: %s'
                      % (label, MAX_BLOCKS, listed)})

        if event_name == 'PostToolUse':
            tool_input = data.get('tool_input')
            file_path = tool_input.get('file_path') if isinstance(tool_input, dict) else None
            folder = get_item_folder(file_path)
            if folder is None:
                return 0
            if folder not in get_touched(agent_key):
                with open(touch_file, 'a', encoding='utf-8') as fh:
                    fh.write(agent_key + '\t' + folder + '\n')
            return 0

        if event_name == 'Stop':
            msg = str(data.get('last_assistant_message') or '')
            if re.search(r'\[no-work-folder\]', msg):
                set_block_count('main', 0)
                return 0

            touched = get_touched('main')
            mentioned = [f for f in noun_mentions(msg) + path_mentions(msg) if f not in touched]
            mentioned = unique(mentioned)
            if not touched and not mentioned:
                return 0

            issues = []
            for c in touched:
                issues += get_folder_issues(c)
            for c in mentioned:
                issues += get_folder_issues(c, lenient=True)
            if not issues:
                set_block_count('main', 0)
                return 0

            send_verdict('main', issues, 'main session', 'Stop')
            return 0

        if event_name == 'SubagentStop':
            agent_type = str(data.get('agent_type') or '')
            if re.search(r'(^|-)planner$', agent_type, re.IGNORECASE):
                label = 'runbook.md'
                test = lambda f: os.path.isfile(os.path.join(f, 'runbook.md'))
            elif re.search(r'(^|-)runner$', agent_type, re.IGNORECASE):
                label = 'run-report.md'
                test = lambda f: os.path.isfile(os.path.join(f, 'run-report.md'))
            elif re.search(r'(^|-)writer$', agent_type, re.IGNORECASE):
                label = 'a draft-*/reply-*/new-* .txt'

                def test(f):
                    try:
                        names = os.listdir(f)
                    except Exception:
                        return False
                    return any(os.path.isfile(os.path.join(f, n))
                               and re.match(r'^(draft[-_].*|reply-.*|new-.*)\.txt$', n, re.IGNORECASE)
                               for n in names)
            else:
                return 0

            folders = get_touched(agent_key)
            if not folders:
                # An agent that wrote through the shell leaves no Write/Edit touch. Read the folders it
                # NAMES in its last message and test the file on disk instead of assuming nothing was written.
                msg = str(data.get('last_assistant_message') or '')
                named = unique(path_mentions(msg) + noun_mentions(msg))
                for f in named:
                    probe = f
                    if not os.path.isdir(probe):
                        alt = os.path.join(WORK_ROOT, 'archive', os.path.basename(f.rstrip('\\/')))
                        if os.path.isdir(alt):
                            probe = alt
                    if os.path.isdir(probe) and test(probe):
                        gate_log('ALLOW SubagentStop %s - %s found on disk in %s' % (agent_type, label, probe))
                        return 0
            issues = []
            if not folders:
                issues.append('%s wrote nothing to a work-item folder under %s (expected %s)' % (agent_type, WORK_ROOT, label))
            else:
                for f in folders:
                    if not test(f):
                        issues.append(f + ' has no ' + label)
            if not issues:
                return 0

            send_verdict(agent_key, issues, agent_type, 'SubagentStop')
            return 0

        return 0
    except Exception as e:
        gate_log('ERROR ' + str(e))
        return 0


if __name__ == '__main__':
    sys.exit(main())
