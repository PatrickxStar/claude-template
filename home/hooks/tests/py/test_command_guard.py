# test_command_guard.py - sandbox copy of command-guard.py against synthesized PreToolUse JSON.
# Mirrors test-command-guard.ps1 case for case. ASCII only.
import os

import hooktest as H


def C(cmd):
    return {'hook_event_name': 'PreToolUse', 'tool_name': 'Bash', 'tool_input': {'command': cmd}}


class CommandGuardTests(H.HookCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = H.sandbox_dir('cmdguard')
        cls.work = os.path.join(cls.tmp, 'Work')
        cls.cfg = H.sandbox_config(cls.tmp)
        cls.hook = H.sandbox_hook('command-guard.py', {'WORK_ROOT': cls.work, 'CONFIG_DIR': cls.cfg, 'ITEM_NOUN': 'ticket'}, cls.tmp)

    @classmethod
    def tearDownClass(cls):
        H.cleanup(cls.tmp)

    # --- forbidden list
    def test_01_forbidden_server_name_deny(self):
        self.check_pre_tool_use(self.hook, C('sqlcmd -S prodserver -Q "select 1"'), 'deny', 'off limits')

    def test_02_other_server_allow(self):
        self.check_pre_tool_use(self.hook, C('sqlcmd -S devbox -Q "select 1"'), 'allow')

    def test_03_outlook_send_deny(self):
        self.check_pre_tool_use(self.hook, C('$m = $ol.CreateItem(0); $m.Send()'), 'deny', 'Never send')

    def test_04_outlook_display_allow(self):
        self.check_pre_tool_use(self.hook, C('$m = $ol.CreateItem(0); $m.Display()'), 'allow')

    # --- state files
    def test_05_set_content_state_json_without_serializer_deny(self):
        self.check_pre_tool_use(self.hook, C('Set-Content ' + os.path.join(self.work, 'system', 'queue.json') + ' $text'), 'deny', 'ConvertTo-Json')

    def test_06_same_with_convertto_json_allow(self):
        self.check_pre_tool_use(self.hook, C('$q | ConvertTo-Json -Depth 5 | Set-Content ' + os.path.join(self.work, 'system', 'queue.json')), 'allow')

    def test_07_forward_slash_path_no_serializer_deny(self):
        self.check_pre_tool_use(self.hook, C('echo x > ' + self.work.replace('\\', '/') + '/system/state.json'), 'deny', 'ConvertTo-Json')

    def test_08_json_outside_system_allow(self):
        self.check_pre_tool_use(self.hook, C('Set-Content ' + os.path.join(self.work, '12345', 'summary.json') + ' $text'), 'allow')

    # --- drafts from the shell
    def test_09_set_content_draft_reply_deny(self):
        self.check_pre_tool_use(self.hook, C('Set-Content ' + os.path.join(self.work, '12345', 'draft-reply.txt') + ' "Hi"'), 'deny', 'Write tool')

    def test_10_redirect_to_reply_case_deny(self):
        self.check_pre_tool_use(self.hook, C('echo hi > ' + os.path.join(self.work, '12345', 'reply-case.txt')), 'deny', 'Write tool')

    def test_11_new_ticket_via_writealltext_deny(self):
        self.check_pre_tool_use(self.hook, C('[IO.File]::WriteAllText("' + os.path.join(self.work, '12345', 'new-ticket.txt') + '", $t)'), 'deny', 'Write tool')

    def test_12_report_line_that_only_mentions_draft_allow(self):
        self.check_pre_tool_use(self.hook, C('Add-Content ' + os.path.join(self.work, '12345', 'findings.md') + ' "wrote draft-reply.txt"'), 'allow')

    def test_13_cat_a_draft_allow(self):
        self.check_pre_tool_use(self.hook, C('cat ' + os.path.join(self.work, '12345', 'draft-reply.txt')), 'allow')

    # --- broken input must allow silently
    def test_14_broken_stdin_not_json(self):
        self.check_broken_stdin(self.hook, 'not json at all')

    def test_15_broken_stdin_empty(self):
        self.check_broken_stdin(self.hook, '')

    def test_16_broken_stdin_null_tool_input(self):
        self.check_broken_stdin(self.hook, '{"tool_input":null}')

    def test_17_broken_stdin_empty_command(self):
        self.check_broken_stdin(self.hook, '{"tool_input":{"command":""}}')
