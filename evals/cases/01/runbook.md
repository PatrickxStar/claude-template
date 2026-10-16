# Runbook 01 v1 - Delegate view opens a blank page
PLANNER-VERDICT: PLAN-READY
FAMILY: identity   OWNER-GUESS: ours
AUDIENCE: B internal non-tech
TWIN: none
PRIOR ART: family_first_moves (identity family: read the target's registration before touching the delegate row), skill work-queue

## What they are actually asking (one sentence, plain English)

Sam picks Jordan Vale in the view-as dropdown and gets a blank page; they want Jordan's account to load.

## Steps (the Runner does these in order and stops on the first MISMATCH)
1. Read the TARGET's registration, not the delegate row: GET <portal admin>/users?email=<Jordan's portal email> with the token in `$env:PORTAL_ADMIN_TOKEN`. Record RegistrationCompleted and UserId for Jordan.
   EXPECT: exactly one user, RegistrationCompleted = true, UserId set.
   IF-NOT: no user, or RegistrationCompleted = false, or UserId null -> Jordan never finished registering, so there is nothing for a delegate to view. The delegate link is not the problem. Continue to step 4. Two users on the same email -> STOP (stop condition 1).
2. Read the delegate row: GET <portal admin>/UserDelegates?delegate=<Sam's UserId>.
   EXPECT: one row whose target UserId equals Jordan's UserId from step 1.
   IF-NOT: no row -> the add last week never saved, continue to step 4 with that finding. Row points at a different UserId -> it was added against a duplicate record; STOP (stop condition 2).
3. Control: from the same delegate list pick one other target Sam is allowed to view and open it the same way.
   EXPECT: that target loads.
   IF-NOT: view-as is broken for Sam as a whole, not for Jordan -> FAMILY changes to portal-session; STOP and hand back.
4. Decide the owner from steps 1-3 using the owner logic below and fill the summary block.
   EXPECT: exactly one branch matches.
   IF-NOT: two branches match -> NEEDS-__USER_FIRST__ with the one question that separates them.

## Writes (only if any)
- None this pass. If step 1 shows an unfinished registration the fix is a registration invite, which is a person's click (STAGE: the exact invite call written to staged-calls.txt, never run here).

## Stop conditions (the Runner hands back to me on any of these)
- Two portal users share Jordan's login email.
- The delegate row targets a UserId that is not Jordan's.

## Owner logic
- Step 1 shows no finished registration -> ours. The fix is finishing Jordan's registration (invite), then the existing delegate row works as is.
- Steps 1 and 2 both normal and step 3 loads -> ours, but a different cause; re-plan from the browser console error on the blank page.
- Step 3 fails -> ours, portal-session family; one runbook for Sam's session, not for Jordan.

## Reply skeleton (facts only, the Writer supplies the words)
- Reader: Sam, bucket B, target 10-35 words
- Must say: the blank page is on Jordan's side (their account setup is not finished), the delegate link is fine, what happens next once Jordan finishes
- Must NOT say: any back-end system name, any promise of a date, "re-add the delegate"
- Escalation needed: no
