# test_lesson_capture.py - sandbox copy of lesson-capture.py with a temp queue file.
# Mirrors test-lesson-capture.ps1 case for case. ASCII only.
import os
import re

import hooktest as H


def P(prompt):
    return {'hook_event_name': 'UserPromptSubmit', 'session_id': 'lc-1', 'cwd': 'C:\\x', 'prompt': prompt}


class LessonCaptureTests(H.HookCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = H.sandbox_dir('lesson')
        cls.queue = os.path.join(cls.tmp, 'system', 'lesson-queue.jsonl')
        cls.hook = H.sandbox_hook('lesson-capture.py', {'QUEUE_FILE': cls.queue}, cls.tmp)

    @classmethod
    def tearDownClass(cls):
        H.cleanup(cls.tmp)

    def queue_lines(self):
        if not os.path.isfile(self.queue):
            return []
        with open(self.queue, 'r', encoding='utf-8') as fh:
            return [l for l in fh.read().split('\n') if l != '']

    def check_capture(self, prompt, expect_capture, queue_like=''):
        before = len(self.queue_lines())
        r = H.invoke_hook(self.hook, H.hook_json(P(prompt)))
        problem = H.health_problem(r)
        self.assertIsNone(problem, problem)
        after = len(self.queue_lines())
        captured = ('additionalContext' in r.stdout) and (after == before + 1)
        self.assertEqual(expect_capture, captured, 'expected capture=%s, got capture=%s | %s' % (expect_capture, captured, r.stdout))
        if not expect_capture:
            self.assertEqual('', r.stdout, r.stdout)
        if expect_capture and queue_like:
            last = self.queue_lines()[-1]
            self.assertTrue(re.search(queue_like, last), 'queue line does not match /%s/: %s' % (queue_like, last))

    # --- corrections are queued
    def test_01_no_use_the_other_path_captured(self):
        self.check_capture('no, use the other path for that file', True, 'no-opener')

    def test_02_from_now_on_always_captured(self):
        self.check_capture('from now on always write the summary first', True, 'standing')

    def test_03_remember_that_captured(self):
        self.check_capture('remember that the QA copy is scrubbed', True, 'remember')

    def test_04_email_and_ssn_redacted(self):
        self.check_capture('dont email bob@example.com about 123-45-6789 again', True, r'\[EMAIL\].*\[SSN\]')

    # --- non-corrections pass silently
    def test_05_thanks_nothing(self):
        self.check_capture('thanks!', False)

    def test_06_slash_command_nothing(self):
        self.check_capture('/work-queue dont skip', False)

    def test_07_scheduled_task_opener_nothing(self):
        self.check_capture('run work-queue now and dont stop', False)

    def test_08_correction_only_inside_pasted_content_nothing(self):
        self.check_capture('please summarize this <pasted_content id="1">no, never do that</pasted_content>', False)

    # --- broken input must allow silently
    def test_09_broken_stdin_not_json(self):
        self.check_broken_stdin(self.hook, 'not json')

    def test_10_broken_stdin_empty(self):
        self.check_broken_stdin(self.hook, '')

    def test_11_broken_stdin_null_prompt(self):
        self.check_broken_stdin(self.hook, '{"prompt":null}')
