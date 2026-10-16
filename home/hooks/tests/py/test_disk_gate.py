# test_disk_gate.py - sandbox copy of disk-gate.py with a temp work root.
# Mirrors test-disk-gate.ps1 case for case. ASCII only.
import os
import time

import hooktest as H


def Stop(sid, msg):
    return {'hook_event_name': 'Stop', 'session_id': sid, 'stop_hook_active': False, 'last_assistant_message': msg}


def Touch(sid, path, agent=''):
    d = {'hook_event_name': 'PostToolUse', 'session_id': sid, 'tool_name': 'Write', 'tool_input': {'file_path': path, 'content': 'x'}}
    if agent:
        d['agent_id'] = agent
    return d


def SubStop(sid, agent_id, agent_type, msg):
    return {'hook_event_name': 'SubagentStop', 'session_id': sid, 'agent_id': agent_id, 'agent_type': agent_type, 'last_assistant_message': msg}


class DiskGateTests(H.HookCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = H.sandbox_dir('diskgate')
        cls.work = os.path.join(cls.tmp, 'Work')
        os.makedirs(os.path.join(cls.work, 'system'), exist_ok=True)
        os.makedirs(os.path.join(cls.work, 'archive'), exist_ok=True)
        cls.hook = H.sandbox_hook('disk-gate.py', {
            'WORK_ROOT': cls.work, 'STATE_DIR': os.path.join(cls.tmp, 'state'),
            'LOG_FILE': os.path.join(cls.tmp, 'disk-gate.log'), 'ITEM_NOUN': 'ticket'}, cls.tmp)
        cls.sid = 'dg-' + time.strftime('%H%M%S')

    @classmethod
    def tearDownClass(cls):
        H.cleanup(cls.tmp)

    def complete(self, folder):
        H.write_text(os.path.join(folder, 'findings.md'), 'done')
        H.write_text(os.path.join(folder, 'summary.json'), '{"status":"open"}')

    def touch(self, sid, path, agent=''):
        H.invoke_hook(self.hook, H.hook_json(Touch(sid, path, agent)))

    # --- Stop, mentions
    def test_01_mentions_ticket_with_no_folder_block(self):
        self.check_stop_event(self.hook, Stop(self.sid + '-a', 'Ticket 199991 is fixed.'), True, '199991')

    def test_02_same_with_no_work_folder_tag_allow(self):
        self.check_stop_event(self.hook, Stop(self.sid + '-b', 'Ticket 199991 is a pure lookup. [no-work-folder]'), False)

    def test_03_bare_pr_number_is_not_a_mention_allow(self):
        self.check_stop_event(self.hook, Stop(self.sid + '-c', 'Merged PR #25587 into main.'), False)

    def test_04_mentions_a_complete_folder_allow(self):
        self.complete(os.path.join(self.work, '199992'))
        self.check_stop_event(self.hook, Stop(self.sid + '-d', 'Ticket 199992 is done.'), False)

    def test_05_mentions_folder_with_only_summary_allow_lenient(self):
        H.write_text(os.path.join(self.work, '199993', 'summary.json'), '{"status":"open"}')
        self.check_stop_event(self.hook, Stop(self.sid + '-e', 'Ticket 199993 is a stub.'), False)

    def test_06_mentions_work_root_path_with_no_folder_block(self):
        self.check_stop_event(self.hook, Stop(self.sid + '-f', 'See ' + os.path.join(self.work, '199994', 'findings.md')), True, '199994')

    def test_07_mentions_system_folder_path_allow_reserved(self):
        self.check_stop_event(self.hook, Stop(self.sid + '-g', 'Updated ' + os.path.join(self.work, 'system', 'known-noise.md')), False)

    # --- Stop, touched folders are strict
    def test_08_touched_folder_without_summary_block(self):
        s = self.sid + '-t'
        self.touch(s, os.path.join(self.work, '199995', 'findings.md'))
        H.write_text(os.path.join(self.work, '199995', 'findings.md'), 'x')
        self.check_stop_event(self.hook, Stop(s, 'All done.'), True, 'summary.json is missing')

    def test_09_summary_that_does_not_parse_block(self):
        H.write_text(os.path.join(self.work, '199995', 'summary.json'), '{not json')
        self.check_stop_event(self.hook, Stop(self.sid + '-t', 'All done.'), True, 'does not parse')

    def test_10_both_files_good_allow(self):
        H.write_text(os.path.join(self.work, '199995', 'summary.json'), '{"status":"open"}')
        self.check_stop_event(self.hook, Stop(self.sid + '-t', 'All done.'), False)

    def test_11_write_under_reports_is_not_a_touch_allow(self):
        s2 = self.sid + '-r'
        self.touch(s2, os.path.join(self.work, 'reports', 'report-today.md'))
        self.check_stop_event(self.hook, Stop(s2, 'Report written.'), False)

    # --- the 2-block cap
    def test_12_third_block_gives_up_with_system_message(self):
        s3 = self.sid + '-cap'
        H.invoke_hook(self.hook, H.hook_json(Stop(s3, 'Ticket 199996 fixed.')))
        H.invoke_hook(self.hook, H.hook_json(Stop(s3, 'Ticket 199996 fixed.')))
        self.check_gave_up(self.hook, Stop(s3, 'Ticket 199996 fixed.'))

    # --- SubagentStop
    def test_13_runner_touched_folder_without_run_report_block(self):
        s4 = self.sid + '-sub'
        self.touch(s4, os.path.join(self.work, '199997', 'run-report.md'), 'agentR')
        os.makedirs(os.path.join(self.work, '199997'), exist_ok=True)
        self.check_stop_event(self.hook, SubStop(s4, 'agentR', 'runner', 'Done.'), True, 'run-report.md')

    def test_14_runner_run_report_present_allow(self):
        H.write_text(os.path.join(self.work, '199997', 'run-report.md'), 'x')
        self.check_stop_event(self.hook, SubStop(self.sid + '-sub', 'agentR', 'runner', 'Done.'), False)

    def test_15_prefixed_agent_type_also_matches_allow(self):
        self.check_stop_event(self.hook, SubStop(self.sid + '-sub', 'agentR', 'ticket-runner', 'Done.'), False)

    def test_16_planner_wrote_via_shell_but_names_folder_with_runbook_allow(self):
        H.write_text(os.path.join(self.work, '199997', 'runbook.md'), 'x')
        self.check_stop_event(self.hook, SubStop(self.sid + '-sub', 'agentP', 'planner', 'Runbook at ' + os.path.join(self.work, '199997', 'runbook.md')), False)

    def test_17_writer_touched_nothing_names_nothing_block(self):
        self.check_stop_event(self.hook, SubStop(self.sid + '-sub', 'agentW', 'writer', 'Draft is in the chat above.'), True, 'wrote nothing')

    def test_18_unknown_agent_type_allow(self):
        self.check_stop_event(self.hook, SubStop(self.sid + '-sub', 'agentX', 'explorer', 'Done.'), False)

    # --- broken input must allow silently
    def test_19_broken_stdin_not_json(self):
        self.check_broken_stdin(self.hook, 'not json')

    def test_20_broken_stdin_empty(self):
        self.check_broken_stdin(self.hook, '')

    def test_21_broken_stdin_no_session(self):
        self.check_broken_stdin(self.hook, '{"hook_event_name":"Stop"}')
