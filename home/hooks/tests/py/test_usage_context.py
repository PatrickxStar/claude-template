# test_usage_context.py - sandbox copy of usage-context.py with a temp usage file.
# Mirrors test-usage-context.ps1 case for case. ASCII only.
import datetime
import os
import re
import time

import hooktest as H


def U():
    return {'hook_event_name': 'UserPromptSubmit', 'session_id': 'uc-1', 'prompt': 'hi there'}


class UsageContextTests(H.HookCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = H.sandbox_dir('usage')
        cls.usage = os.path.join(cls.tmp, 'system', 'usage-state.json')
        os.makedirs(os.path.dirname(cls.usage), exist_ok=True)
        cls.hook = H.sandbox_hook('usage-context.py', {'USAGE_FILE': cls.usage}, cls.tmp)

    @classmethod
    def tearDownClass(cls):
        H.cleanup(cls.tmp)

    def check_line(self, like, expect_output=True):
        r = H.invoke_hook(self.hook, H.hook_json(U()))
        problem = H.health_problem(r)
        self.assertIsNone(problem, problem)
        if not expect_output:
            self.assertEqual('', r.stdout, 'stdout: ' + r.stdout)
            return
        ctx = ''
        if isinstance(r.parsed, dict) and isinstance(r.parsed.get('hookSpecificOutput'), dict):
            ctx = str(r.parsed['hookSpecificOutput'].get('additionalContext', ''))
        self.assertTrue(re.search(like, ctx), 'line does not match /%s/: %s' % (like, ctx))

    @staticmethod
    def now_iso(hours_ago=0):
        return (datetime.datetime.now() - datetime.timedelta(hours=hours_ago)).strftime('%Y-%m-%dT%H:%M:%S')

    def test_01_no_usage_file_nothing(self):
        self.check_line('', False)

    def test_02_fresh_file_one_line_with_both_numbers(self):
        H.write_text(self.usage, '{"checkedAt":"' + self.now_iso() + '","fiveHourPct":12,"weeklyAllPct":30}')
        self.check_line('5-hour 12%.*week-all 30%')

    def test_03_with_a_rationed_model_its_numbers_appear(self):
        H.write_text(self.usage, '{"checkedAt":"' + self.now_iso() + '","fiveHourPct":12,"weeklyAllPct":30,"capModel":"BigModel",'
                                 '"weeklyModelPct":20,"modelTodayPct":5,"modelDailyCapPct":20,"modelCapHit":false}')
        self.check_line('BigModel: week 20%, today 5% of 20% cap')

    def test_04_cap_hit_prefix(self):
        H.write_text(self.usage, '{"checkedAt":"' + self.now_iso() + '","fiveHourPct":12,"weeklyAllPct":30,"capModel":"BigModel",'
                                 '"weeklyModelPct":25,"modelTodayPct":21,"modelDailyCapPct":20,"modelCapHit":true}')
        self.check_line('^DAILY CAP HIT for BigModel')

    def test_05_three_hours_old_stale_prefix(self):
        H.write_text(self.usage, '{"checkedAt":"' + self.now_iso(3) + '","fiveHourPct":12,"weeklyAllPct":30}')
        t = time.time() - 3 * 3600
        os.utime(self.usage, (t, t))
        self.check_line('^USAGE IS STALE')

    def test_06_broken_file_nothing(self):
        H.write_text(self.usage, 'not json')
        self.check_line('', False)
