# Review Comments: Add RoostGuard to all RPC handlers for roost lifecycle management

| Field       | Value |
|-------------|-------|
| PR          | hawksbury/hawksbury#34429 |
| HEAD        | 27748881a1cb5eb58ed39c3ed2095038cb0cc62a |

## Comments

### C1
node: 1.1.1
type: inline
status: active
source: reviewer
file: hawksbury/core/src/main/java/com/hawksbury/legacy/RoostGuard.java
lines: L19-40
side: right
tree_rev: 1
created: 2026-02-24T11:00:00Z

The catch block defaults to SILENT on any exception, including unexpected ones.
If the FeatureFlags client throws a network error or deserialization bug, this
swallows it silently. Consider logging the exception even in SILENT mode --
`logger.warn("Failed to read roost mode for %s, defaulting to SILENT", endpointName, e)`
would preserve the safe default while making failures visible.

### C2
node: root
type: top-level
status: active
source: reviewer
tree_rev: 1
created: 2026-02-24T11:15:00Z

Overall the guard pattern is clean and well-structured. The three-mode approach
(SILENT/CHIRP/BLOCK) with per-roost LaunchDarkly targeting gives good operational
flexibility. Main concern is the silent exception swallowing noted in C1.

### C3
node: 2.1.5
type: inline
status: active
source: reviewer
file: service/src/main/java/com/hawksbury/plumage/ChargeNestInternalApi.java
lines: L25-29
side: right
tree_rev: 1
created: 2026-02-24T11:20:00Z

This handler is in the `plumage` package but follows the same injection pattern
as the `sanctuary/v2` handlers. Is there a reason the field is injected at L26
instead of at the top of the field list like the other handlers? Probably just
where it fell alphabetically, but worth confirming the DI framework doesn't
care about field order.

### C4
node: 3
type: top-level
status: active
source: reviewer
tree_rev: 1
created: 2026-02-24T11:30:00Z

The commented-out guard approach for 13 active-traffic roosts makes me uneasy.
That's 13 files with dead code that will need a follow-up PR to activate. Is
there a timeline for the follow-up? If this sits for months, new contributors
will be confused by the commented-out calls and might remove them thinking
they're leftovers.

### C5
node: 2.1.3
type: inline
status: deleted
source: reviewer
file: service/src/main/java/com/hawksbury/sanctuary/v2/SetPlumagePhotoAppApi.java
lines: L15-15
side: right
tree_rev: 1
created: 2026-02-24T11:35:00Z

(Reviewer retracted this comment after realizing the import order is correct.)
