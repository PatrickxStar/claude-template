#!/usr/bin/env python3
# voice-gate.py - Python twin of voice-gate.ps1 (same stdin JSON in, same stdout JSON out).
# PreToolUse hook, matcher "Write|Edit".
# Checks every draft shape: draft-*.txt / draft_*.txt, reply-*.txt, new-<item>*.txt.
# A file whose name carries "to-<your first name>" is a note to you, not a send: only the
# dash and hedge checks apply. Also refuses a .sql under the work root that carries a
# transaction wrapper (staged SQL is plain statements the person runs with one keystroke).
# Denies a save that breaks the voice rules; prints nothing to allow.
# Any parse error or non-matching file allows silently (never blocks real work).
# Standard library only. ASCII only. The constants below are swapped by the tests: keep
# them as one r'...' literal per line (raw, so a Windows path with backslashes survives).

import json
import os
import re
import sys

WORK_ROOT = r'__WORK_ROOT__'
CONFIG_DIR = r'__CLAUDE_HOME__/hooks/config'
USER_FIRST = r'__USER_FIRST__'
ITEM_NOUN = r'__ITEM__'
CEILING_AB = 45     # words, bucket A/B, unless the body is numbered click steps

EM_DASH = '\u2014'
EN_DASH = '\u2013'
VOICE_LINE = re.compile(r'^\s*VOICE:\s*(?:bucket\s*)?([A-F])\b', re.IGNORECASE | re.MULTILINE)


def emit(obj):
    sys.stdout.write(json.dumps(obj, separators=(',', ':')))
    sys.stdout.flush()


def norm(p):
    return str(p).replace('\\', '/')


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


def deny(reason):
    emit({'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason}})


def main():
    try:
        data = json.loads(sys.stdin.buffer.read().decode('utf-8'))
    except Exception:
        return 0
    try:
        tool_input = data.get('tool_input')
        if not isinstance(tool_input, dict):
            return 0
        file_path = tool_input.get('file_path')
        if not file_path:
            return 0
        file_path = str(file_path)
        file_name = re.split(r'[\\/]', file_path.rstrip('\\/'))[-1]
        if file_name == '':
            return 0

        text = None
        if tool_input.get('content') is not None:
            text = str(tool_input['content'])
        elif tool_input.get('new_string') is not None:
            text = str(tool_input['new_string'])

        # ---- staged SQL: no transaction wrapper, live or commented --------------------
        root_esc = re.escape(norm(WORK_ROOT).rstrip('/'))
        if re.search(r'\.sql$', file_name, re.IGNORECASE) and re.match('^' + root_esc + '/', norm(file_path), re.IGNORECASE):
            if text:
                m = re.search(r'\b(BEGIN\s+TRAN(SACTION)?|COMMIT|ROLLBACK)\b', text, re.IGNORECASE)
                if m:
                    deny("SQL gate: '" + m.group(1) + "' found. Staged SQL is plain statements only - no BEGIN TRAN / COMMIT / "
                         "ROLLBACK, live or commented. The person running it must get a saved write from one keystroke.")
            return 0

        name_pat = r'^(draft[-_].*|reply-.*|new-' + re.escape(ITEM_NOUN) + r'.*)\.txt$'
        if not re.match(name_pat, file_name, re.IGNORECASE):
            return 0
        to_me = re.search('to-' + re.escape(USER_FIRST), file_name, re.IGNORECASE) is not None
        if not text:
            return 0

        # ---- bucket: search the raw text (header may carry the VOICE: line) ----------
        bucket = 'B'
        bm = VOICE_LINE.search(text)
        if bm:
            bucket = bm.group(1).upper()
        elif tool_input.get('new_string') is not None and os.path.exists(file_path):
            # an Edit carries only the changed text: the bucket lives in the file on disk
            try:
                with open(file_path, 'r', encoding='utf-8-sig') as fh:
                    on_disk = fh.read()
                dm = VOICE_LINE.search(on_disk)
                if dm:
                    bucket = dm.group(1).upper()
            except Exception:
                pass

        # ---- strip a header in the first 12 lines: up to and including a line that is
        #      exactly "---" or a line containing "copy everything below this line" ------
        lines = re.split(r'\r\n|\r|\n', text)
        header_end = -1
        for i in range(min(12, len(lines))):
            if lines[i].strip() == '---':
                header_end = i
                break
            if re.search('copy everything below this line', lines[i], re.IGNORECASE):
                header_end = i
                break
        if header_end < 0:
            # no marker: a VOICE: line in the first 6 lines is the header, and it is never sent
            for i in range(min(6, len(lines))):
                if re.match(r'^\s*VOICE:', lines[i], re.IGNORECASE):
                    header_end = i
        if header_end >= 0:
            body_lines = lines[header_end + 1:]
        else:
            body_lines = lines
        body = '\n'.join(body_lines)

        reasons = []

        # ---- em dash / en dash ----
        if EM_DASH in body:
            reasons.append('em dash found')
        if EN_DASH in body:
            reasons.append('en dash found')

        # ---- typed sign-off ----
        sign_off = False
        for l in body_lines:
            lt = l.strip()
            if lt == USER_FIRST or lt == '- ' + USER_FIRST or lt == '-' + USER_FIRST:
                sign_off = True
                break
        if sign_off and not to_me:
            reasons.append("typed sign-off found ('" + USER_FIRST + "')")

        # ---- back-end system names (bucket C and notes to you are exempt) ----
        if bucket != 'C' and not to_me:
            for p in read_patterns(os.path.join(CONFIG_DIR, 'backend-names.txt')):
                try:
                    m = re.search(r'\b(' + p + r')\b', body, re.IGNORECASE)
                    if m:
                        reasons.append("back-end name '" + m.group(1) + "'")
                        break
                except Exception:
                    pass

        # ---- never say how sure ----
        for p in read_patterns(os.path.join(CONFIG_DIR, 'hedge-words.txt')):
            try:
                m = re.search(p, body, re.IGNORECASE)
                if m:
                    reasons.append("says how sure - '" + m.group(0) + "'")
                    break
            except Exception:
                pass

        # ---- word ceiling for bucket A/B (unless numbered click steps; not for notes to you) ----
        if bucket in ('A', 'B') and not to_me:
            non_blank = [l for l in body_lines if l.strip() != '']
            words = [w for w in re.split(r'\s+', ' '.join(non_blank)) if w != '']
            word_count = len(words)
            has_steps = any(re.match(r'^\s*\d+[\.\)]\s', l) for l in non_blank)
            if word_count > CEILING_AB and not has_steps:
                reasons.append('%d words for bucket %s (ceiling %d) - cut it or make it click steps'
                               % (word_count, bucket, CEILING_AB))

        if reasons:
            deny('Voice gate: ' + '; '.join(reasons) + '. Fix and save again.')
        return 0
    except Exception:
        return 0


if __name__ == '__main__':
    sys.exit(main())
