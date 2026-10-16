#!/usr/bin/env python3
# lesson-capture.py - Python twin of lesson-capture.ps1 (same stdin JSON in, same stdout JSON out).
# UserPromptSubmit hook. When your prompt looks like a correction ("no, ...", "don't ...",
# "actually ...", "from now on ...", "remember ..."), it:
#   1. appends one redacted JSON line to <work root>/system/lesson-queue.jsonl
#   2. reminds the model (additionalContext) to save a durable rule to memory WITH the why.
# Review the queue with /lesson-review. It never blocks a prompt.
# Any parse error allows silently (never blocks real work).
# Standard library only. ASCII only. The constants below are swapped by the tests: keep
# them as one r'...' literal per line (raw, so a Windows path with backslashes survives).

import datetime
import json
import os
import re
import sys
import uuid

QUEUE_FILE = r'__WORK_ROOT__/system/lesson-queue.jsonl'

PATTERNS = [
    ('no-opener', r'^(no|nope|nah)\b'),
    ('dont', r"\b(don'?t|do not|never)\b"),
    ('stop-doing', r'\bstop (doing|using|adding|making|writing|sending|asking)\b'),
    ('actually', r'\bactually\b'),
    ('wrong', r"\b(wrong|that'?s not|that is not|not what i)\b"),
    ('instead', r'\binstead\b'),
    ('standing', r'\b(always|from now on|going forward|next time)\b'),
    ('remember', r'\bremember\b'),
    ('why-did-you', r'\bwhy (did|would) you\b'),
    ('should-have', r"\byou (should|shouldn'?t) have\b"),
]


def emit(obj):
    sys.stdout.write(json.dumps(obj, separators=(',', ':')))
    sys.stdout.flush()


def main():
    try:
        data = json.loads(sys.stdin.buffer.read().decode('utf-8'))
    except Exception:
        return 0
    try:
        prompt = str(data.get('prompt') or '')
        # Pasted text is not your own words.
        prompt = re.sub(r'<pasted_content[^>]*>.*?</pasted_content[^>]*>', ' ', prompt, flags=re.DOTALL)
        if prompt.strip() == '':
            return 0
        trim = prompt.strip()
        if len(trim) < 12:
            return 0
        if trim.startswith('/') or trim.startswith('<'):
            return 0   # slash commands, system/event payloads
        if re.match(r'^(run|start) (work-queue|the queue|the worker)', trim, re.IGNORECASE):
            return 0   # scheduled-task prompts

        head = trim[:400]
        hits = [k for k, p in PATTERNS if re.search(p, head, re.IGNORECASE)]
        if not hits:
            return 0

        # redact before anything touches disk: SSNs, emails, long digit runs
        clean = trim
        if len(clean) > 600:
            clean = clean[:600] + ' ...'
        clean = re.sub(r'\b\d{3}-\d{2}-\d{4}\b', '[SSN]', clean)
        clean = re.sub(r'[\w.+-]+@[\w-]+\.[\w.-]+', '[EMAIL]', clean)
        clean = re.sub(r'\b\d{9,}\b', '[NUM]', clean)

        now = datetime.datetime.now()
        entry = {
            'id': now.strftime('%Y%m%d%H%M%S') + '-' + uuid.uuid4().hex[:6],
            'ts': now.strftime('%Y-%m-%dT%H:%M:%S'),
            'sessionId': str(data.get('session_id') or ''),
            'cwd': str(data.get('cwd') or ''),
            'matched': ','.join(hits),
            'prompt': clean,
        }
        try:
            d = os.path.dirname(QUEUE_FILE)
            if d and not os.path.isdir(d):
                os.makedirs(d, exist_ok=True)
            with open(QUEUE_FILE, 'a', encoding='utf-8') as fh:
                fh.write(json.dumps(entry, separators=(',', ':')) + '\n')
        except Exception:
            pass

        ctx = ('lesson-capture: this prompt looks like a correction (' + entry['matched'] + '). If it is a durable rule, '
               'save it to memory now as a feedback memory WITH the why and how to apply, and say so in one line. '
               'If it is a one-off instruction, just do it. Queued as ' + entry['id'] + ' for /lesson-review.')
        emit({'hookSpecificOutput': {'hookEventName': 'UserPromptSubmit', 'additionalContext': ctx}})
        return 0
    except Exception:
        return 0


if __name__ == '__main__':
    sys.exit(main())
