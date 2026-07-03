---
position_column: todo
position_ordinal: '8880'
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