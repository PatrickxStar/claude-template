# hooktest.py - shared helpers for the Python hook tests (the twin of lib-hooktest.ps1).
#   python3 -m unittest discover home/hooks/tests/py
#
# Every hook is tested through a SANDBOX COPY: the hook text with its top-of-file
# "NAME = r'...'" constants swapped for temp paths. If a constant is not found, the
# sandbox refuses to build (raises) instead of silently running against real files.
# The JSON goes in as raw UTF-8 bytes on stdin, the way Claude Code sends it.
# Keep this file ASCII only: build special characters with '\u2014' escapes.

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

HOOK_DIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'py'))

EM_DASH = '\u2014'
EN_DASH = '\u2013'


class Result(object):
    def __init__(self, timed_out, exit_code, stdout, stderr):
        self.timed_out = timed_out
        self.exit_code = exit_code
        self.stdout = stdout
        self.stderr = stderr
        self.parsed = None
        self.parse_ok = True
        if stdout != '':
            try:
                self.parsed = json.loads(stdout)
            except Exception:
                self.parse_ok = False


def invoke_hook(script, text, timeout=30):
    data = text.encode('utf-8') if isinstance(text, str) else text
    try:
        p = subprocess.run([sys.executable, script], input=data, stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE, timeout=timeout)
    except subprocess.TimeoutExpired:
        return Result(True, -1, '', '')
    return Result(False, p.returncode, p.stdout.decode('utf-8', 'replace').strip(),
                  p.stderr.decode('utf-8', 'replace').strip())


def hook_json(data):
    return json.dumps(data)


def health_problem(r):
    # Common health checks every hook run must meet: finished, exit 0, no stderr, stdout is JSON or empty.
    if r.timed_out:
        return 'timed out'
    if r.exit_code != 0:
        return 'exit code %d (2 would BLOCK)' % r.exit_code
    if r.stderr != '':
        return 'stderr: ' + r.stderr
    if not r.parse_ok:
        return 'stdout is not JSON: ' + r.stdout
    return None


def decision(r):
    if r.parsed is None:
        return 'allow'
    if isinstance(r.parsed, dict):
        h = r.parsed.get('hookSpecificOutput')
        if isinstance(h, dict) and h.get('permissionDecision') == 'deny':
            return 'deny'
        if r.parsed.get('decision') == 'block':
            return 'block'
    return 'other'


def sandbox_dir(tag):
    return tempfile.mkdtemp(prefix='hooktest-' + tag + '-')


def sandbox_hook(hook_name, variables, sandbox):
    # Rewrite each "NAME = r'...'" constant at the top of the hook. Every name must exist.
    src = os.path.join(HOOK_DIR, hook_name)
    with open(src, 'r', encoding='utf-8') as fh:
        text = fh.read()
    for k, v in variables.items():
        pat = r'(?m)^' + re.escape(k) + r"\s*=\s*r?'[^']*'"
        if not re.search(pat, text):
            raise RuntimeError("sandbox: %s = '...' not found at the top of %s - the hook changed, update the test" % (k, hook_name))
        literal = k + ' = ' + repr(str(v))
        text = re.sub(pat, lambda m: literal, text, count=1)
    os.makedirs(sandbox, exist_ok=True)
    dst = os.path.join(sandbox, hook_name)
    with open(dst, 'w', encoding='utf-8') as fh:
        fh.write(text)
    return dst


def sandbox_config(sandbox):
    # A config folder with known rules, so a test never depends on what the user filled in.
    cfg = os.path.join(sandbox, 'config')
    os.makedirs(cfg, exist_ok=True)
    write_lines(os.path.join(cfg, 'forbidden-commands.txt'), [
        '# test rules',
        r'\bprodserver\b' + '\t' + 'That server is off limits from Claude.',
        r'\.Send\(\)|Send-MailMessage|\.SendAndSaveCopy\(' + '\t' + 'Never send. Compose with .Display().',
    ])
    write_lines(os.path.join(cfg, 'backend-names.txt'), ['# test', 'Vault', 'SQL', 'API', 'Redshift', 'S3 bucket'])
    write_lines(os.path.join(cfg, 'hedge-words.txt'), ['# test', r'\bconfidence\b', r'\bconfident\b', r"\bi'?m sure\b",
                                                        r'\bi am sure\b', r'\blikely\b', r'\bprobably\b'])
    return cfg


def write_lines(path, lines):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(lines) + '\n')


def write_text(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(text)


def words(n):
    pool = ['the', 'portal', 'login', 'is', 'reset', 'now', 'and', 'she', 'can', 'sign', 'in', 'again', 'today']
    return ' '.join(pool[i % len(pool)] for i in range(n))


class HookCase(unittest.TestCase):
    """Base class: one assertion helper per expectation shape the PowerShell suite uses."""

    def check_pre_tool_use(self, script, data, expect, reason_like=''):
        # PreToolUse expectation: 'deny' or 'allow' (allow = print nothing). Optional reason regex for a deny.
        r = invoke_hook(script, hook_json(data))
        problem = health_problem(r)
        self.assertIsNone(problem, problem)
        got = decision(r)
        reason = ''
        if got == 'deny':
            reason = str(r.parsed['hookSpecificOutput'].get('permissionDecisionReason', ''))
        self.assertEqual(expect, got, 'expected %s, got %s | %s' % (expect, got, reason or r.stdout))
        if expect == 'allow':
            self.assertEqual('', r.stdout, 'allow must print nothing: ' + r.stdout)
        if expect == 'deny' and reason_like:
            self.assertTrue(re.search(reason_like, reason, re.IGNORECASE), 'reason does not match /%s/: %s' % (reason_like, reason))

    def check_stop_event(self, script, data, expect_block, reason_like=''):
        # Stop / SubagentStop expectation: block or not. Optional reason regex.
        r = invoke_hook(script, hook_json(data))
        problem = health_problem(r)
        self.assertIsNone(problem, problem)
        blocked = re.search(r'"decision":\s*"block"', r.stdout) is not None
        self.assertEqual(expect_block, blocked, 'expected block=%s, got block=%s | %s' % (expect_block, blocked, r.stdout[:140]))
        if not expect_block and r.stdout != '':
            self.assertIn('systemMessage', r.stdout, 'an allow may only print a systemMessage: ' + r.stdout)
        if expect_block and reason_like:
            self.assertTrue(re.search(reason_like, r.stdout, re.IGNORECASE), 'reason does not match /%s/: %s' % (reason_like, r.stdout))

    def check_gave_up(self, script, data):
        # after the cap: a systemMessage and no decision
        r = invoke_hook(script, hook_json(data))
        problem = health_problem(r)
        self.assertIsNone(problem, problem)
        self.assertIn('systemMessage', r.stdout, r.stdout)
        self.assertNotIn('"decision"', r.stdout, r.stdout)

    def check_broken_stdin(self, script, bad):
        # broken input must allow silently
        r = invoke_hook(script, bad)
        problem = health_problem(r)
        self.assertIsNone(problem, problem)
        self.assertEqual('', r.stdout, 'broken stdin must print nothing: ' + r.stdout)


def cleanup(path):
    shutil.rmtree(path, ignore_errors=True)
