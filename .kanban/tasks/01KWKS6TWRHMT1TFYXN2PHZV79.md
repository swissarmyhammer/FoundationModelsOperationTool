---
position_column: todo
position_ordinal: 8b80
title: Add test for OperationCLIDriver.runNonOperationCommand's success path
---
Sources/OperationsCLI/OperationCLIDriver.swift:120-132

Coverage: 95.1% (77/81 lines)

Uncovered lines: 106, 124, 127-128:

```swift
private static func dispatch(command: ParsableCommand) async -> CLIResult {
    guard let opCommand = command as? any OperationCommand else {
        return await runNonOperationCommand(command: command)
    }
    guard let dispatch = CLIRuntime.current?.dispatchByCommandType[ObjectIdentifier(type(of: opCommand))] else {
        return CLIResult(output: "Internal error: no dispatcher registered for '\(type(of: opCommand))'.", exitCode: 1)  // 106
    }
    ...
}

private static func runNonOperationCommand(command: ParsableCommand) async -> CLIResult {
    var mutableCommand = command
    do {
        if var asyncCommand = mutableCommand as? AsyncParsableCommand {
            try await asyncCommand.run()          // 124
        } else {
            try mutableCommand.run()
        }
        return CLIResult(output: "", exitCode: 0)  // 128
    } catch {
        return errorResult(for: error)
    }
}
```

Line 106 is a genuinely defensive "should never happen" internal-consistency check (the registry is always populated consistently with the commands `CLIRegistryBuilder` emits) — likely not practically testable without deliberately corrupting `CLIRuntime.current`, so treat as low priority / possibly skip.

Lines 124 and 127-128 are the real gap: no CLI-driver test exercises a parsed command that is NOT an `OperationCommand` leaf and completes without throwing (e.g. an intermediate node reached with no further subcommand, or any non-operation `AsyncParsableCommand`/`ParsableCommand` whose `run()` succeeds and returns normally rather than throwing `CleanExit`/`ExitCode`). Add a test that drives such a scenario through `OperationCLIDriver.run(arguments:)` and asserts a `CLIResult(output: "", exitCode: 0)`.