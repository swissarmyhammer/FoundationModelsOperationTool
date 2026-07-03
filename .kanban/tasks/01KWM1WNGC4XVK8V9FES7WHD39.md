---
comments:
- actor: wballard
  id: 01kwm9cje3xz5xfnqc1020k281
  text: |-
    Implemented option (b) (the preferred fix per the task): extended `CLIDriverFallbackLeafTests.fallbackLeafRoundTripsToTheSamePayloadTheResolverAccepts()` in Tests/OperationsCLITests/CLIDriverTests.swift, keeping the name, rather than renaming it.

    After the existing exit-code/substring checks on `driver.run(arguments:)`'s output, the test now:
    1. Parses `result.output` back into a `GeneratedContent` via `GeneratedContent(json:)`.
    2. Runs it through `OperationResolver().resolveParameters(_:matching:)` against `ArchiveNoteCLIFixture.parameterMetadata` — the same resolution `OperationTool.call` performs on every payload.
    3. Asserts `resolution.missingRequired.isEmpty`.
    4. Asserts the resolved `id` still equals `"note-1"`.

    This genuinely proves the round-trip claim: the operation's own JSON output, fed back in as a payload for the same operation, is accepted by the resolver and preserves field values — not just a one-way "output contains a substring" check.

    Sanity-checked the new assertion is load-bearing: temporarily changed the expected `id` to a wrong value, reran `swift test --filter fallbackLeafRoundTripsToTheSamePayloadTheResolverAccepts`, confirmed it failed with the expected message, then restored the correct value and reran green.

    No production code under Sources/ touched; no other pre-existing test in the file modified.

    Verification: `swift build` clean (zero warnings), `swift test` full run green — 174 tests across all 4 test targets (74/34/44/22), zero failures, zero warnings. Adversarial double-check agent dispatched to independently verify.

    Leaving in doing per implement workflow — ready for /review.
  timestamp: 2026-07-03T15:26:05.763975+00:00
position_column: doing
position_ordinal: '80'
title: Fix misleading name on fallbackLeafRoundTripsToTheSamePayloadTheResolverAccepts
---
Discovered by the local review engine while working ^qtfg8ry (unrelated to that task's diff — this test predates it).

Tests/OperationsCLITests/CLIDriverTests.swift's `CLIDriverFallbackLeafTests.fallbackLeafRoundTripsToTheSamePayloadTheResolverAccepts()` test name claims a round-trip ("RoundTrips" in the name), but the body only exercises one direction: driving `driver.run(arguments:)` and checking the printed JSON contains the expected field. It never parses the JSON output back and confirms it round-trips to the same payload the resolver would accept.

Either rename the test to describe what it actually asserts (e.g. `fallbackLeafProducesTheExpectedJSONFields`), or extend it to actually parse the output JSON and verify the round-trip claim the name makes.