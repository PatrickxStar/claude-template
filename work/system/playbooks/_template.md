# Playbook: <name>

STATUS: PREP-ONLY   (set to AUTO only after VERIFY and REVERSE have been run by hand once)

MATCHES
-------
<the __ITEM__ wording this covers, the phrases people use, precedent ids>

NOT THIS PLAYBOOK
-----------------
- <look-alike> -> <where it goes instead>

PRECONDITIONS (all must pass or fall back to prep + lane "call")
--------------------------------------------------------------
1. Requester is <who is allowed to ask for this>.
2. The value to set is stated verbatim in the __ITEM__ (never guessed or derived).
3. The record resolves cleanly: exactly ONE, not soft-deleted. EVALUATE WITH: <the exact read>.
4. <the check that separates this shape from the tangled one>. EVALUATE WITH: <read>, exit/result <x> passes.
5. The write path is available NOW: `$env:<VAR>` is set (read with [Environment]::GetEnvironmentVariable('<VAR>','User')).

EXECUTE
-------
Part 0 - read and record the PRIOR value: <the exact read>. Write it into autopilot-log.md before anything else.
Part 1 - <the exact call: method, URL, body, or the statement shape with values substituted>.
          Expected response: <what success looks like>. <what a specific error means and that it STOPS>.

VERIFY
------
<the read that shows the NEW state - a GET or SELECT, never a status code. If it does not show
the new state, the write did not happen: MISMATCH, not CLEAN.>

REVERSE
-------
<the exact call that puts the PRIOR value back. Same mechanism, same order.>

AFTER
-----
VOICE: facts below, words from system\voice-checklist.md
- draft-reply.txt facts: <what changed, in one clause; what the requester does next, if anything>.
  Do NOT restate the value they supplied. Do NOT pre-answer a problem nobody reported.
- draft-to-<first>.txt for <each other person the fix touches>, if any.
- summary.json: lane "ready", synopsis "[AUTO] <what changed> - good to close."
- autopilot-log.md one line: `- <date HH:mm> <id> <playbook> - <call> (prior: <value>; reverse: <call>)`.
  A staged or blocked run writes STAGED in the line.
