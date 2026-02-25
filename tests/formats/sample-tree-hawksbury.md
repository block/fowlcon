# Review Tree: Add RoostGuard to all RPC handlers for roost lifecycle management

| Field       | Value |
|-------------|-------|
| PR          | hawksbury/hawksbury#34429 |
| HEAD        | 27748881a1cb5eb58ed39c3ed2095038cb0cc62a |
| Revision    | 1 |
| Tree Built  | 2026-02-24T10:30:00Z |
| Updated     | 2026-02-24T11:45:00Z |

## Tree

- [reviewed] 1. Core: The roost guard mechanism (new code)
  context: |
    New singleton guard that controls roost (endpoint) lifecycle via
    feature flags. Three modes per roost name: SILENT (production default,
    noop), CHIRP (test default, logs calls), BLOCK (rejects calls).
    Injected via @Singleton/@Inject. 47 lines total across 2 new files.
  - [reviewed] 1.1. RoostGuard class
    context: |
      40-line singleton. Takes a FeatureFlags client via @Inject.
      checkRoost() reads a flag keyed by roost name, switches on the
      mode enum. The catch block defaults to SILENT if the flag is not
      configured -- safe default, but swallows all exceptions including
      unexpected ones.
    - [reviewed] 1.1.1. Feature flag integration and checkRoost() method {comment}
      context: |
        Reads hawksbury-roost-mode flag with per-roost targeting.
        The flag key is the roost name string, enabling individual
        control without code changes or redeployment.
      files:
      - hawksbury/core/src/main/java/com/hawksbury/legacy/RoostGuard.java L1-18 (+18/-0)
      - hawksbury/core/src/main/java/com/hawksbury/legacy/RoostGuard.java L19-40 (+22/-0)
    - [reviewed] 1.1.2. SILENT/CHIRP/BLOCK mode switching
      context: |
        Three-valued enum in a separate file. SILENT = noop,
        CHIRP = log + continue, BLOCK = reject with
        UnsupportedOperationException. Separate file for reuse
        in test infrastructure.
      files:
      - hawksbury/core/src/main/java/com/hawksbury/legacy/RoostMode.java L1-7 (+7/-0)
  - [reviewed] 1.2. Test infrastructure
    context: |
      HawksburyFakeFeatureFlagsModule updated: imports the new mode
      enum, overrides hawksbury-roost-mode to CHIRP (LOG equivalent)
      so integration tests exercise the guard in logging mode.
    - [reviewed] 1.2.1. Feature flag override for tests
      files:
      - service-integration-test/src/test/java/com/hawksbury/testing/HawksburyFakeFeatureFlagsModule.java L53-53 (+1/-0)
      - service-integration-test/src/test/java/com/hawksbury/testing/HawksburyFakeFeatureFlagsModule.java L673-674 (+2/-0)
    - [reviewed] 1.2.2. Test file import adjustments
      context: "Three test files needed the new import for compilation"
      files:
      - integration-tests/flock/src/test/java/com/hawksbury/flock/tags/ReserveTagInternalApiTest.java L10-12 (+3/-0)
      - service/src/test/java/com/hawksbury/plumage/PostProcessCvvAndExpirationInternalApiTest.java L8-10 (+3/-0)
      - service/src/test/java/com/hawksbury/flock/tags/DeleteReservedTagInternalApiTest.java L5-8 (+4/-0)

- [accepted] 2. Active guard: zero-traffic roosts (guard enabled) {variation}
  context: |
    Roosts with zero recent traffic get the guard actively enabled.
    Pattern: add import, inject field, call checkRoost() at method top.
    When the feature flag is toggled to BLOCK, these endpoints reject
    traffic -- confirming they are truly unused before decommissioning.
  - [accepted] 2.1. Standard pattern (+3 lines, 2 hunks) {variation}
    context: |
      The common case: file already has jakarta.inject.Inject imported.
      Three additions across two diff hunks: import in hunk 1, field
      injection + checkRoost() call together in hunk 2.
    - [accepted] 2.1.1. Example: CloseNestAppApi
      context: |
        Typical v2 app handler. Import lands in sorted position among
        existing imports. Field injection added above existing @Inject
        fields. checkRoost() call is first line of the RPC method body.
      files:
      - service/src/main/java/com/hawksbury/sanctuary/v2/CloseNestAppApi.java L38-38 (+1/-0)
      - service/src/main/java/com/hawksbury/sanctuary/v2/CloseNestAppApi.java L48-55 (+2/-0)
    - [accepted] 2.1.2. RefundPaymentAppApi {repeat}
      files:
      - service/src/main/java/com/hawksbury/sanctuary/v2/activity/RefundPaymentAppApi.java L12-12 (+1/-0)
      - service/src/main/java/com/hawksbury/sanctuary/v2/activity/RefundPaymentAppApi.java L28-32 (+2/-0)
    - [accepted] 2.1.3. SetPlumagePhotoAppApi {repeat comment}
      files:
      - service/src/main/java/com/hawksbury/sanctuary/v2/SetPlumagePhotoAppApi.java L15-15 (+1/-0)
      - service/src/main/java/com/hawksbury/sanctuary/v2/SetPlumagePhotoAppApi.java L34-38 (+2/-0)
    - [accepted] 2.1.4. SyncContactsAppApi {repeat}
      files:
      - service/src/main/java/com/hawksbury/sanctuary/v2/contacts/SyncContactsAppApi.java L8-8 (+1/-0)
      - service/src/main/java/com/hawksbury/sanctuary/v2/contacts/SyncContactsAppApi.java L22-26 (+2/-0)
    - [accepted] 2.1.5. ChargeNestInternalApi {repeat comment}
      files:
      - service/src/main/java/com/hawksbury/plumage/ChargeNestInternalApi.java L10-10 (+1/-0)
      - service/src/main/java/com/hawksbury/plumage/ChargeNestInternalApi.java L25-29 (+2/-0)
    - [accepted] 2.1.6. ForceBalanceCheckInternalApi {repeat}
      files:
      - service/src/main/java/com/hawksbury/aviary/ForceBalanceCheckInternalApi.java L5-5 (+1/-0)
      - service/src/main/java/com/hawksbury/aviary/ForceBalanceCheckInternalApi.java L18-22 (+2/-0)
    - [accepted] 2.1.7. SuspendFlockMemberInternalApi {repeat}
      files:
      - service/src/main/java/com/hawksbury/aviary/SuspendFlockMemberInternalApi.java L14-14 (+1/-0)
      - service/src/main/java/com/hawksbury/aviary/SuspendFlockMemberInternalApi.java L30-34 (+2/-0)
    - [accepted] 2.1.8. AddSeedInternalApi {repeat}
      files:
      - service/src/main/java/com/hawksbury/migration/AddSeedInternalApi.java L7-7 (+1/-0)
      - service/src/main/java/com/hawksbury/migration/AddSeedInternalApi.java L20-24 (+2/-0)
    - [accepted] 2.1.9. GetSeedRouteInternalApi {repeat}
      files:
      - service/src/main/java/com/hawksbury/migration/GetSeedRouteInternalApi.java L11-11 (+1/-0)
      - service/src/main/java/com/hawksbury/migration/GetSeedRouteInternalApi.java L28-32 (+2/-0)
    - [accepted] 2.1.10. GetNestingAssetsInternalApi {repeat}
      files:
      - service/src/main/java/com/hawksbury/nesting/GetNestingAssetsInternalApi.java L5-5 (+1/-0)
      - service/src/main/java/com/hawksbury/nesting/GetNestingAssetsInternalApi.java L16-20 (+2/-0)
  - [accepted] 2.2. Extra import pattern (+4 lines, 2 hunks) {variation}
    context: |
      These handlers lacked a pre-existing jakarta.inject.Inject import.
      Same guard pattern, but one additional import line. 11 handlers in
      the real PR; 2 shown in this sample.
    - [accepted] 2.2.1. Example: ExecuteFeederContractAppApi
      context: |
        Already @Deprecated, throws on call. Gets the guard anyway
        for consistent lifecycle tracking. Needed the extra Inject import
        because the file only used Guice-style injection previously.
      files:
      - service/src/main/java/com/hawksbury/sanctuary/v2/ExecuteFeederContractAppApi.java L6-6 (+1/-0)
      - service/src/main/java/com/hawksbury/sanctuary/v2/ExecuteFeederContractAppApi.java L19-24 (+3/-0)
    - [accepted] 2.2.2. GetCreationMechanismsInternalApi {repeat}
      files:
      - service/src/main/java/com/hawksbury/api/GetCreationMechanismsInternalApi.java L8-8 (+1/-0)
      - service/src/main/java/com/hawksbury/api/GetCreationMechanismsInternalApi.java L22-27 (+3/-0)

- [accepted] 3. Commented-out guard: active roosts (guard prepared but dormant) {variation comment}
  context: |
    Roosts with active traffic get the guard installed but commented out
    with "// Still in use". The infrastructure is in place so the guard
    can be uncommented when traffic migrates away. Same 2-3 hunk structure
    as node 2, but the checkRoost() line is commented.
  - [reviewed] 3.1. Example: GetFlockProfileAppApi
    context: |
      High-traffic profile endpoint. The commented call includes the
      roost name so it can be uncommented as-is when ready. Three hunks
      in this file because the field injection and call are in separate
      diff contexts.
    - [reviewed] 3.1.1. Import added
      files:
      - service/src/main/java/com/hawksbury/sanctuary/v2/GetFlockProfileAppApi.java L11-11 (+1/-0)
    - [reviewed] 3.1.2. Field injection added
      files:
      - service/src/main/java/com/hawksbury/sanctuary/v2/GetFlockProfileAppApi.java L40-40 (+1/-0)
    - [reviewed] 3.1.3. checkRoost() COMMENTED OUT with "// Still in use"
      files:
      - service/src/main/java/com/hawksbury/sanctuary/v2/GetFlockProfileAppApi.java L53-53 (+1/-0)
  - [accepted] 3.2. GetPaymentAppApi {repeat}
    files:
    - service/src/main/java/com/hawksbury/sanctuary/v2/GetPaymentAppApi.java L9-9 (+1/-0)
    - service/src/main/java/com/hawksbury/sanctuary/v2/GetPaymentAppApi.java L35-35 (+1/-0)
    - service/src/main/java/com/hawksbury/sanctuary/v2/GetPaymentAppApi.java L48-48 (+1/-0)
  - [accepted] 3.3. LinkPerchAppApi {repeat}
    files:
    - service/src/main/java/com/hawksbury/sanctuary/v2/LinkPerchAppApi.java L14-14 (+1/-0)
    - service/src/main/java/com/hawksbury/sanctuary/v2/LinkPerchAppApi.java L42-42 (+1/-0)
    - service/src/main/java/com/hawksbury/sanctuary/v2/LinkPerchAppApi.java L56-56 (+1/-0)
  - [accepted] 3.4. InitiateSessionAppApi {repeat}
    files:
    - service/src/main/java/com/hawksbury/hatching/InitiateSessionAppApi.java L7-7 (+1/-0)
    - service/src/main/java/com/hawksbury/hatching/InitiateSessionAppApi.java L30-30 (+1/-0)
    - service/src/main/java/com/hawksbury/hatching/InitiateSessionAppApi.java L44-44 (+1/-0)
  - [accepted] 3.5. RegisterHatchlingAppApi {repeat}
    files:
    - service/src/main/java/com/hawksbury/hatching/RegisterHatchlingAppApi.java L12-12 (+1/-0)
    - service/src/main/java/com/hawksbury/hatching/RegisterHatchlingAppApi.java L38-38 (+1/-0)
    - service/src/main/java/com/hawksbury/hatching/RegisterHatchlingAppApi.java L52-52 (+1/-0)
  - [accepted] 3.6. TransferPerchAppApi {repeat}
    files:
    - service/src/main/java/com/hawksbury/sanctuary/v2/TransferPerchAppApi.java L18-18 (+1/-0)
    - service/src/main/java/com/hawksbury/sanctuary/v2/TransferPerchAppApi.java L45-45 (+1/-0)
    - service/src/main/java/com/hawksbury/sanctuary/v2/TransferPerchAppApi.java L58-58 (+1/-0)
  - [accepted] 3.7. GetBandingVerificationsInternalApi {repeat}
    files:
    - service/src/main/java/com/hawksbury/aviary/GetBandingVerificationsInternalApi.java L6-6 (+1/-0)
    - service/src/main/java/com/hawksbury/aviary/GetBandingVerificationsInternalApi.java L22-22 (+1/-0)
    - service/src/main/java/com/hawksbury/aviary/GetBandingVerificationsInternalApi.java L35-35 (+1/-0)
  - [accepted] 3.8. FeedChickInternalApi {repeat}
    files:
    - service/src/main/java/com/hawksbury/feeding/FeedChickInternalApi.java L4-4 (+1/-0)
    - service/src/main/java/com/hawksbury/feeding/FeedChickInternalApi.java L18-18 (+1/-0)
    - service/src/main/java/com/hawksbury/feeding/FeedChickInternalApi.java L30-30 (+1/-0)
  - [accepted] 3.9. GetMigrationPatternInternalApi {repeat}
    files:
    - service/src/main/java/com/hawksbury/migration/GetMigrationPatternInternalApi.java L11-11 (+1/-0)
    - service/src/main/java/com/hawksbury/migration/GetMigrationPatternInternalApi.java L28-28 (+1/-0)
    - service/src/main/java/com/hawksbury/migration/GetMigrationPatternInternalApi.java L40-40 (+1/-0)
  - [accepted] 3.10. CreateFlockMemberInternalApi {repeat}
    files:
    - service/src/main/java/com/hawksbury/flock/CreateFlockMemberInternalApi.java L9-9 (+1/-0)
    - service/src/main/java/com/hawksbury/flock/CreateFlockMemberInternalApi.java L32-32 (+1/-0)
    - service/src/main/java/com/hawksbury/flock/CreateFlockMemberInternalApi.java L45-45 (+1/-0)
  - [accepted] 3.11. GetPerchLinksInternalApi {repeat}
    files:
    - service/src/main/java/com/hawksbury/perches/GetPerchLinksInternalApi.java L7-7 (+1/-0)
    - service/src/main/java/com/hawksbury/perches/GetPerchLinksInternalApi.java L24-24 (+1/-0)
    - service/src/main/java/com/hawksbury/perches/GetPerchLinksInternalApi.java L36-36 (+1/-0)
  - [accepted] 3.12. VerifyBandAppApi {repeat}
    files:
    - service/src/main/java/com/hawksbury/sanctuary/v2/VerifyBandAppApi.java L10-10 (+1/-0)
    - service/src/main/java/com/hawksbury/sanctuary/v2/VerifyBandAppApi.java L34-34 (+1/-0)
    - service/src/main/java/com/hawksbury/sanctuary/v2/VerifyBandAppApi.java L47-47 (+1/-0)
  - [accepted] 3.13. SetNestTagAppApi {repeat}
    files:
    - service/src/main/java/com/hawksbury/sanctuary/v2/tags/SetNestTagAppApi.java L8-8 (+1/-0)
    - service/src/main/java/com/hawksbury/sanctuary/v2/tags/SetNestTagAppApi.java L26-26 (+1/-0)
    - service/src/main/java/com/hawksbury/sanctuary/v2/tags/SetNestTagAppApi.java L38-38 (+1/-0)

- [reviewed] 4. Exclusions
  context: |
    PR description mentions two handlers intentionally excluded from the
    guard rollout. Neither appears in the diff. Both have operational
    reasons documented by the author.
  - [reviewed] 4.1. FetchNestDataInternalApi
    context: "Author states: Tier-0 critical API, too risky to add guard"
  - [reviewed] 4.2. FeedSourceRpc
    context: "Author states: library class, not a directly editable roost"

- [pending] 5. CLAUDE.md update (meta)
  context: |
    Updates the repo's AI agent instructions with two new pitfalls
    discovered during this change: module visibility for new files
    and alphabetical import ordering.
  files:
  - CLAUDE.md L153-158 (+3/-1)

## Description Verification

| # | Claim | Status | Evidence |
|---|-------|--------|----------|
| 1 | "12 inactive/zero-traffic handlers: guard is active" | verified | 12 handlers in node 2 (10 standard + 2 extra-import) |
| 2 | "13 active handlers: guard is commented out" | verified | 13 handlers in node 3 |
| 3 | "FetchNestDataInternalApi explicitly excluded (Tier-0 API)" | verified | Noted in node 4.1; not in diff |
| 4 | "FeedSourceRpc excluded (library class)" | verified | Noted in node 4.2; not in diff |
| 5 | CLAUDE.md changes | undocumented | Node 5 -- not mentioned in PR description |
| 6 | Test infrastructure changes | undocumented | Node 1.2 -- 4 test files changed, not mentioned in PR description |

## Coverage

Total files in diff: 32
Files mapped to tree: 32
Unmapped files: none
