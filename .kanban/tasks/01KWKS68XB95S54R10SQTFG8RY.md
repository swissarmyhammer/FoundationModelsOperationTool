---
comments:
- actor: wballard
  id: 01kwm1wweavg87p67707mbdb8q
  text: |-
    Implemented: added FallbackOperationCommandRunTests.runPrintsTheSameJSONOperationPayloadWouldProduce() in Tests/OperationsCLITests/CLIDriverTests.swift, which directly constructs FallbackOperationCommand<ArchiveNoteCLIFixture>() (the existing macro-less fallback fixture used by CLIDriverFallbackLeafTests), sets rawArguments, calls run(), and asserts the captured stdout equals operationPayload().jsonString.

    No existing stdout-capture pattern existed in this repo's tests (swift-argument-parser's own AssertExecuteCommand spawns a subprocess via Process+Pipe, which isn't viable here since FallbackOperationCommand is an internal type with no standalone executable). Added a small in-process `captureStandardOutput` helper (fd 1 dup2/Pipe redirect + restore) scoped to this test file.

    Sanity-checked the test isn't vacuous: temporarily appended a bogus suffix to the expected string, reran, watched it fail with the real captured JSON shown in the diff output, then reverted to the correct assertion.

    Verification: `swift package clean && swift build` — clean, zero warnings. `swift test` — all 4 targets green, 84 tests total (30 + 32 + 22 + ... ), including the new suite, with no interference from parallel test execution (confirmed by output showing the new test interleaved with other suites, all passing).

    Local /review flagged one finding, but it's in pre-existing code untouched by this diff (fallbackLeafRoundTripsToTheSamePayloadTheResolverAccepts's misleading name) — confirmed via `git diff` that the flagged line isn't part of my change. Filed as a separate follow-up task rather than fixing in-scope, since this task is a coverage-backfill for FallbackOperationCommand.run() only and must not touch unrelated code.

    Leaving task in doing per /implement's process — ready for /review.
  timestamp: 2026-07-03T13:15:11.690610+00:00
position_column: doing
position_ordinal: '80'
title: Add test for FallbackOperationCommand.run()'s direct-invocation print behavior
---
Sources/OperationsCLI/FallbackOperationCommand.swift:50-52

Coverage: 75.2% (97/129 lines)

Uncovered lines: 50-52:

```swift
internal mutating func run() async throws {
    print(operationPayload().jsonString)
}
```

Per its doc comment, this mirrors the macro-generated `Command.run()`'s print-only behavior for parity when the fallback leaf is driven directly, outside `OperationCLIDriver` (which always intercepts before `run()` runs). No test invokes `FallbackOperationCommand.run()` directly. Add a test that constructs a `FallbackOperationCommand<SomeFixtureOp>`, calls `run()`, and captures stdout to assert it printed the same JSON `operationPayload()` would produce (mirroring however `Command.run()`'s own print-parity is already tested, if such a test exists for the macro-generated leaf).