#!/usr/bin/env python3
# plain-talk-gate.py - Python twin of plain-talk-gate.ps1 (same stdin JSON in, same stdout JSON out).
# Stop hook. The last message of a turn is what you read. It may not carry the two
# fingerprints you call out most: an em/en dash, and a "how sure I am" phrase
# (config/hedge-words.txt). Fenced code blocks, inline code and quoted lines ("> ...")
# are ignored. Blocks once per distinct message and at most 5 times per session, then
# allows and tells you in a system message. Any parse error allows silently.
# Standard library only. ASCII only. The constants below are swapped by the tests: keep
# them as one r'...' literal per line (raw, so a Windows path with backslashes survives).

import datetime
import hashlib
import json
import os
import re
import sys
import time

STATE_DIR = r'__CLAUDE_HOME__/hooks/state'
LOG_FILE = r'__CLAUDE_HOME__/hooks/logs/plain-talk-gate.log'
CONFIG_DIR = r'__CLAUDE_HOME__/hooks/config'
MAX_BLOCKS = 5

EM_DASH = '\u2014'
EN_DASH = '\u2013'


def emit(obj):
    sys.stdout.write(json.dumps(obj, separators=(',', ':')))
    sys.stdout.flush()


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


def read_patterns(path):
    out = []
    if not os.path.isfile(path):
        return out
    with open(path, 'r', encoding='utf-8-sig') as fh:
        for line in fh:
            t = line.strip()
            if t == '' or t.startswith('#'):
                continue
            out.append(t)
    return out


def main():
    try:
        data = json.loads(sys.stdin.buffer.read().decode('utf-8'))
    except Exception:
        return 0
    try:
        if str(data.get('hook_event_name') or '') != 'Stop':
            return 0
        msg = str(data.get('last_assistant_message') or '')
        if msg.strip() == '':
            return 0
        sid = re.sub(r'[^\w-]', '', str(data.get('session_id') or ''))
        if sid == '':
            return 0

        # what you read: drop fenced code, inline code, and quoted lines
        clean = re.sub(r'```.*?```', ' ', msg, flags=re.DOTALL)
        clean = re.sub(r'`[^`\r\n]*`', ' ', clean)
        clean = '\n'.join(l for l in re.split(r'\r?\n', clean) if not re.match(r'^\s*>', l))

        reasons = []
        if EM_DASH in clean:
            reasons.append('an em dash (use a spaced hyphen " - ")')
        if EN_DASH in clean:
            reasons.append('an en dash (use a spaced hyphen " - ")')
        for p in read_patterns(os.path.join(CONFIG_DIR, 'hedge-words.txt')):
            try:
                m = re.search(p, clean, re.IGNORECASE)
                if m:
                    reasons.append('a "how sure" word - "' + m.group(0).strip() + '"')
                    break
            except Exception:
                pass
        if not reasons:
            return 0

        os.makedirs(STATE_DIR, exist_ok=True)
        cutoff = time.time() - 3 * 24 * 3600
        for name in os.listdir(STATE_DIR):
            if name.startswith('plain-talk-'):
                p = os.path.join(STATE_DIR, name)
                try:
                    if os.path.getmtime(p) < cutoff:
                        os.remove(p)
                except Exception:
                    pass
        state_file = os.path.join(STATE_DIR, 'plain-talk-' + sid + '.txt')   # one line per blocked message hash

        digest = hashlib.sha1(msg.encode('utf-8')).hexdigest().upper()[:16]
        seen = []
        if os.path.isfile(state_file):
            with open(state_file, 'r', encoding='utf-8-sig') as fh:
                seen = [l.rstrip('\r\n') for l in fh if l.rstrip('\r\n') != '']

        listed = '; '.join(reasons)
        if digest in seen:
            gate_log('ALLOW-REPEAT %s %s : %s' % (sid, digest, listed))
            return 0
        if len(seen) >= MAX_BLOCKS:
            gate_log('GAVE-UP %s after %d blocks: %s' % (sid, MAX_BLOCKS, listed))
            emit({'systemMessage': 'plain-talk-gate: the last answer still has %s after %d reminders this session.'
                  % (listed, MAX_BLOCKS)})
            return 0
        with open(state_file, 'a', encoding='utf-8') as fh:
            fh.write(digest + '\n')
        gate_log('BLOCK %s %s (%d/%d): %s' % (sid, digest, len(seen) + 1, MAX_BLOCKS, listed))
        emit({'decision': 'block',
              'reason': 'plain-talk-gate: your last message has %s. Rewrite it plainly - spaced hyphens, no confidence '
                        'words, facts and the next click - then stop again.' % listed})
        return 0
    except Exception as e:
        gate_log('ERROR ' + str(e))
        return 0


if __name__ == '__main__':
    sys.exit(main())
