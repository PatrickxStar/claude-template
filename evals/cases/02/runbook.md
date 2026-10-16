# Runbook 02 v1 - One policy from a batch is missing from the client list
PLANNER-VERDICT: PLAN-READY
FAMILY: data feed   OWNER-GUESS: vendor
AUDIENCE: B internal non-tech
TWIN: none
PRIOR ART: family_first_moves (data feed family: find the record at the source feed before anything downstream), skill work-queue

## What they are actually asking (one sentence, plain English)

Policy 55-4410 was issued last Tuesday, two siblings from the same batch show in the advisor's client list and this one does not; they want it visible before Friday.

## Steps (the Runner does these in order and stops on the first MISMATCH)
1. Find the record at the source: open the raw feed file for last Tuesday's batch from the data provider and search it for 55-4410. In the same file confirm the two sibling policies that DID arrive are present, so the file is the right one.
   EXPECT: the siblings are in the file; 55-4410 is either present or absent.
   IF-NOT: the siblings are not in the file -> wrong file or wrong day; STOP (stop condition 1).
2. If 55-4410 is in the raw file: read our import log for that file and find the line for 55-4410.
   EXPECT: a rejected or skipped line with a reason.
   IF-NOT: no line at all -> the file was only partly read; continue, the owner is ours.
3. If 55-4410 is NOT in the raw file: read the next two daily files from the same provider.
   EXPECT: it appears in a later file, or in none of them.
   IF-NOT: not applicable; record which files were read.
4. Decide the owner from steps 1-3 using the owner logic below and fill the summary block.
   EXPECT: exactly one branch matches.
   IF-NOT: two branches match -> NEEDS-__USER_FIRST__ with the one question that separates them.

## Writes (only if any)
- None. Re-importing a file is a bulk action and is never automated: if step 2 shows a reject on our side, STAGE the single-record re-import in staged-calls.txt with the verification read after it.

## Stop conditions (the Runner hands back to me on any of these)
- The sibling policies are not in the file that was read.
- The provider's file for last Tuesday cannot be opened.

## Owner logic
- 55-4410 absent from every provider file -> vendor. The provider never sent it. The reply is a handoff to the provider contact with the policy number and the batch date, not a promise.
- 55-4410 present in the file and rejected by our import -> ours. The reject reason names the fix; stage it.
- 55-4410 arrives in a later file -> nobody; it was late, not lost. Reply with when it will show.

## Reply skeleton (facts only, the Writer supplies the words)
- Reader: the requester, bucket B, target 10-35 words
- Must say: where the policy stopped (never sent by the provider / rejected on our side / arrived late), who is handling it, what the advisor sees and when
- Must NOT say: any back-end system name, "pushed it through", a date unless the fix is staged on our side
- Escalation needed: yes if vendor -> provider support contact, facts: policy 55-4410, batch date, the two sibling numbers that did arrive
