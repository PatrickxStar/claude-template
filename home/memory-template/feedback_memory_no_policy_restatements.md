---
name: feedback_memory_no_policy_restatements
description: Memory never restates a rule a hook enforces or an organization policy - the hook is the rule, the memory would only drift
metadata:
  type: feedback
---

A rule that lives in a hook (`__CLAUDE_HOME__\hooks\`) or in an organization policy is not
written into memory, a skill, or CLAUDE.md a second time.

**Why:** two copies of a rule drift apart; the copy that is not enforced is the one that
gets read, and then the model argues with the hook.

**How to apply:** when a correction is really "the hook should have caught that", fix or
add the hook and record only a pointer ("enforced by command-guard"). When a rule has broken
twice in prose, it becomes a hook.
