# test_plain_talk_gate.py - sandbox copy of plain-talk-gate.py against synthesized Stop JSON.
# Mirrors test-plain-talk-gate.ps1 case for case. ASCII only.
import os
import time

import hooktest as H

EM = H.EM_DASH


def S(sid, msg):
    return {'hook_event_name': 'Stop', 'session_id': sid, 'stop_hook_active': False, 'last_assistant_message': msg}


class PlainTalkGateTests(H.HookCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = H.sandbox_dir('plaintalk')
        cls.cfg = H.sandbox_config(cls.tmp)
        cls.hook = H.sandbox_hook('plain-talk-gate.py', {
            'STATE_DIR': os.path.join(cls.tmp, 'state'), 'LOG_FILE': os.path.join(cls.tmp, 'plain-talk-gate.log'), 'CONFIG_DIR': cls.cfg}, cls.tmp)
        cls.sid = 'pt-' + time.strftime('%H%M%S')

    @classmethod
    def tearDownClass(cls):
        H.cleanup(cls.tmp)

    # --- the two fingerprints
    def test_01_em_dash_in_prose_block(self):
        self.check_stop_event(self.hook, S(self.sid + '-a', 'The feed is fine ' + EM + ' the portal is not.'), True, 'em dash')

    def test_02_clean_plain_answer_allow(self):
        self.check_stop_event(self.hook, S(self.sid + '-b', 'The feed is fine - the portal is not. Next click: refresh the page.'), False)

    def test_03_likely_in_prose_block(self):
        self.check_stop_event(self.hook, S(self.sid + '-c', 'This is likely the carrier feed.'), True, 'how sure')

    def test_04_unlikely_allow_word_edge(self):
        self.check_stop_event(self.hook, S(self.sid + '-d', 'This is unlikely to repeat.'), False)

    def test_05_i_am_sure_block(self):
        self.check_stop_event(self.hook, S(self.sid + '-e', 'I am sure the fix landed.'), True, 'how sure')

    # --- code and quotes are ignored
    def test_06_em_dash_only_in_fenced_block_allow(self):
        self.check_stop_event(self.hook, S(self.sid + '-f', 'Run this:\n```sql\nSELECT 1 ' + EM + ' two\n```'), False)

    def test_07_em_dash_only_in_inline_code_allow(self):
        self.check_stop_event(self.hook, S(self.sid + '-g', 'The title is `Merged ' + EM + ' cases missing`.'), False)

    def test_08_em_dash_only_in_quoted_line_allow(self):
        self.check_stop_event(self.hook, S(self.sid + '-h', 'She wrote:\n> policies ' + EM + ' missing\nI checked the feed.'), False)

    # --- loop guards
    def test_09_first_time_block(self):
        self.check_stop_event(self.hook, S(self.sid + '-i', 'Same message ' + EM + ' twice.'), True)

    def test_10_same_message_again_allow_no_loop(self):
        self.check_stop_event(self.hook, S(self.sid + '-i', 'Same message ' + EM + ' twice.'), False)

    def test_11_sixth_distinct_message_gives_up_with_system_message(self):
        cap = self.sid + '-cap'
        for n in range(1, 6):
            H.invoke_hook(self.hook, H.hook_json(S(cap, 'Message %d %s different.' % (n, EM))))
        self.check_gave_up(self.hook, S(cap, 'Message 6 ' + EM + ' different.'))

    # --- broken input must allow silently
    def test_12_broken_stdin_not_json(self):
        self.check_broken_stdin(self.hook, 'not json')

    def test_13_broken_stdin_empty(self):
        self.check_broken_stdin(self.hook, '')

    def test_14_broken_stdin_no_session(self):
        self.check_broken_stdin(self.hook, '{"hook_event_name":"Stop"}')
