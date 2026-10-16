# test_voice_gate.py - sandbox copy of voice-gate.py against synthesized PreToolUse JSON.
# Mirrors test-voice-gate.ps1 case for case. ASCII only.
import os

import hooktest as H

EM = H.EM_DASH
EN = H.EN_DASH
NL = '\n'


def W(path, content):
    return {'hook_event_name': 'PreToolUse', 'tool_name': 'Write', 'tool_input': {'file_path': path, 'content': content}}


def E(path, old, new):
    return {'hook_event_name': 'PreToolUse', 'tool_name': 'Edit', 'tool_input': {'file_path': path, 'old_string': old, 'new_string': new}}


class VoiceGateTests(H.HookCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = H.sandbox_dir('voice')
        cls.work = os.path.join(cls.tmp, 'Work')
        cls.cfg = H.sandbox_config(cls.tmp)
        cls.hook = H.sandbox_hook('voice-gate.py', {'WORK_ROOT': cls.work, 'CONFIG_DIR': cls.cfg, 'USER_FIRST': 'Sam', 'ITEM_NOUN': 'ticket'}, cls.tmp)
        cls.draft = os.path.join(cls.work, '125000', 'draft-reply.txt')
        os.makedirs(os.path.dirname(cls.draft), exist_ok=True)

    @classmethod
    def tearDownClass(cls):
        H.cleanup(cls.tmp)

    # --- core rules
    def test_01_em_dash_deny(self):
        self.check_pre_tool_use(self.hook, W(self.draft, 'VOICE: B' + NL + '---' + NL + 'Hi Mary! Her portal is fixed ' + EM + ' try again now.' + NL + 'Thanks!'), 'deny', 'em dash')

    def test_02_en_dash_deny(self):
        self.check_pre_tool_use(self.hook, W(self.draft, 'VOICE: B' + NL + '---' + NL + 'Hi Mary! Fixed ' + EN + ' try again.'), 'deny', 'en dash')

    def test_03_bucket_b_12_word_clean_allow(self):
        self.check_pre_tool_use(self.hook, W(self.draft, 'VOICE: B | 12 words' + NL + '---' + NL + 'Hi Mary! I reset her portal login, she can sign in now.'), 'allow')

    def test_04_findings_with_em_dash_allow(self):
        self.check_pre_tool_use(self.hook, W(os.path.join(self.work, '125000', 'findings.md'), 'Root cause ' + EM + ' the user was blocked. Likely fixed.'), 'allow')

    def test_05_edit_new_string_vault_voice_d_deny(self):
        self.check_pre_tool_use(self.hook, E(self.draft, 'x', 'VOICE: D' + NL + '---' + NL + 'Hello, the Vault login for this agent is reset.'), 'deny', 'Vault')

    def test_06_70_words_with_numbered_steps_allow(self):
        steps = ('VOICE: B' + NL + '---' + NL + 'Hi Mary! Here is how to find it:' + NL
                 + '1. Open the app and click the Agents tab at the top of the page' + NL
                 + '2. Search the agent by name and open the profile page' + NL
                 + '3. Click Contracts, then pick the carrier row you need' + NL
                 + '4. Scroll to Details and click the Edit button' + NL
                 + '5. Change the level, save, and refresh the page to confirm it' + NL
                 + 'Let me know how it goes. ' + H.words(12))
        self.check_pre_tool_use(self.hook, W(self.draft, steps), 'allow')

    def test_07_trailing_line_sam_deny(self):
        self.check_pre_tool_use(self.hook, W(self.draft, 'VOICE: B' + NL + '---' + NL + 'Hi Mary! I reset her login.' + NL + 'Thanks,' + NL + 'Sam'), 'deny', 'sign-off')

    def test_08_the_word_likely_deny(self):
        self.check_pre_tool_use(self.hook, W(self.draft, 'VOICE: B' + NL + '---' + NL + 'Hi Mary! This is likely the feed.'), 'deny', 'likely')

    def test_09_unlikely_not_caught_allow(self):
        self.check_pre_tool_use(self.hook, W(self.draft, 'VOICE: B' + NL + '---' + NL + 'Hi Mary! It is unlikely to happen again.'), 'allow')

    def test_10_bucket_c_naming_sql_allow(self):
        self.check_pre_tool_use(self.hook, W(self.draft, 'VOICE: C' + NL + '---' + NL + 'Hey Richie - the SQL update ran and the API call returns 200 now. thanks!'), 'allow')

    def test_11_reply_file_naming_redshift_deny(self):
        self.check_pre_tool_use(self.hook, W(os.path.join(self.tmp, 'reply-CS-4410.txt'), 'VOICE: D' + NL + '---' + NL + 'Hello, the Redshift load finished.'), 'deny', 'Redshift')

    def test_12_no_header_70_words_no_steps_deny(self):
        self.check_pre_tool_use(self.hook, W(self.draft, H.words(70)), 'deny', 'ceiling 45')

    def test_13_voice_header_plus_copy_marker_40_words_allow(self):
        content = ('------' + NL + '  DRAFT REPLY' + NL + '  VOICE:  B internal  40w' + NL + '------' + NL
                   + '  v v v  copy everything below this line  v v v' + NL + NL + H.words(40))
        self.check_pre_tool_use(self.hook, W(self.draft, content), 'allow')

    def test_14_first_line_voice_header_names_vault_allow(self):
        self.check_pre_tool_use(self.hook, W(self.draft, 'VOICE: B (internal, Vault reset done) | 9 words' + NL + NL + 'Hi Mary! Her login is reset, she can sign in.'), 'allow')

    # --- Edit reads the bucket from the file on disk when new_string has no VOICE line
    def test_15_edit_bucket_c_on_disk_names_sql_allow(self):
        H.write_text(self.draft, 'VOICE: C | 20 words' + NL + '---' + NL + 'Hey Richie - old text here. thanks!')
        self.check_pre_tool_use(self.hook, E(self.draft, 'old text here', 'the SQL fix ran'), 'allow')

    def test_16_edit_bucket_d_on_disk_names_vault_deny(self):
        H.write_text(self.draft, 'VOICE: D | 20 words' + NL + '---' + NL + 'Hello, old text here.')
        self.check_pre_tool_use(self.hook, E(self.draft, 'old text here', 'the Vault login is reset'), 'deny', 'Vault')

    def test_17_edit_bucket_e_on_disk_50_words_allow(self):
        H.write_text(self.draft, 'VOICE: E | 50 words' + NL + '---' + NL + 'Hi Mike, old text here.')
        self.check_pre_tool_use(self.hook, E(self.draft, 'old text here', H.words(50)), 'allow')

    # --- every draft shape; notes to you
    def test_18_new_ticket_with_em_dash_deny(self):
        self.check_pre_tool_use(self.hook, W(os.path.join(self.tmp, 'new-ticket.txt'), 'VOICE: C' + NL + '---' + NL + 'Hey team ' + EM + ' can someone look?'), 'deny', 'em dash')

    def test_19_draft_underscore_naming_vault_deny(self):
        self.check_pre_tool_use(self.hook, W(os.path.join(self.tmp, 'draft_reply.txt'), 'VOICE: B' + NL + '---' + NL + 'Hi Mary! Your Vault login is reset.'), 'deny', 'Vault')

    def test_20_note_to_sam_not_a_draft_name_allow(self):
        self.check_pre_tool_use(self.hook, W(os.path.join(self.tmp, 'note-to-sam.txt'), 'The Vault user was blocked ' + EM + ' fixed.'), 'allow')

    def test_21_draft_to_sam_vault_70_words_allow(self):
        self.check_pre_tool_use(self.hook, W(os.path.join(self.tmp, 'draft-to-sam.txt'), 'VOICE: B' + NL + '---' + NL + 'The Vault user was blocked. ' + H.words(70)), 'allow')

    def test_22_draft_to_sam_em_dash_deny(self):
        self.check_pre_tool_use(self.hook, W(os.path.join(self.tmp, 'draft-to-sam.txt'), 'VOICE: B' + NL + '---' + NL + 'Fixed ' + EM + ' see findings.'), 'deny', 'em dash')

    def test_23_draft_to_sam_likely_deny(self):
        self.check_pre_tool_use(self.hook, W(os.path.join(self.tmp, 'draft-to-sam.txt'), 'VOICE: B' + NL + '---' + NL + 'It is likely the feed.'), 'deny', 'likely')

    # --- staged SQL
    def test_24_staged_sql_with_commit_deny(self):
        self.check_pre_tool_use(self.hook, W(os.path.join(self.work, '125000', 'staged-fix.sql'), 'UPDATE t SET x = 1;' + NL + '-- COMMIT'), 'deny', 'SQL gate')

    def test_25_staged_sql_plain_statements_allow(self):
        self.check_pre_tool_use(self.hook, W(os.path.join(self.work, '125000', 'staged-fix.sql'), 'UPDATE t SET x = 1;' + NL + 'SELECT x FROM t;'), 'allow')

    def test_26_sql_outside_work_root_with_begin_tran_allow(self):
        self.check_pre_tool_use(self.hook, W(os.path.join(self.tmp, 'repo', 'migrate.sql'), 'BEGIN TRAN; UPDATE t SET x = 1; COMMIT;'), 'allow')

    # --- broken input must allow silently
    def test_27_broken_stdin_not_json(self):
        self.check_broken_stdin(self.hook, 'not json at all')

    def test_28_broken_stdin_empty(self):
        self.check_broken_stdin(self.hook, '')

    def test_29_broken_stdin_null_tool_input(self):
        self.check_broken_stdin(self.hook, '{"tool_input":null}')

    def test_30_broken_stdin_empty_file_path(self):
        self.check_broken_stdin(self.hook, '{"tool_input":{"file_path":""}}')
