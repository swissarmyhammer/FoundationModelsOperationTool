---
comments:
- actor: wballard
  id: 01kwm6rmf1xg7ewfe62aaj001a
  text: |-
    Investigated ArgumentParser (swift-argument-parser, checked out at .build/checkouts/swift-argument-parser) behavior before writing anything, per the task's request.

    Findings:
    - `ParsableCommand`'s default `run()` (the extension in `Parsable Types/ParsableCommand.swift`) unconditionally throws `CleanExit.helpRequest(self)` — there is no conditional here, it always throws.
    - `AsyncParsableCommand` declares its own `run() async throws` requirement but has no default implementation for it; a conforming type that doesn't override `run()` resolves to `ParsableCommand`'s sync default (Swift permits a non-async function to satisfy an async requirement), which also always throws.
    - ArgumentParser's own built-in `HelpCommand` (auto-added as a `help` child to every non-leaf node) has an explicit `run() throws { throw CommandError(...: .helpRequested(...)) }` — also always throws.
    - `--help`/`--version`/`--experimental-dump-help` are intercepted inside `CommandParser.checkForBuiltInFlags`, which throws directly from `parse()`/`asyncParseAsRoot()` *before* a command value is ever returned — so those requests never even reach `dispatch(command:)`/`runNonOperationCommand` in the first place (`parseAndDispatch`'s own `catch` handles them).
    - No `defaultSubcommand` is configured anywhere in this codebase (`grep` confirmed zero usages), so there's no ArgumentParser mechanism that could substitute a non-throwing terminal command either.

    Every non-`OperationCommand` `ParsableCommand`/`AsyncParsableCommand` reachable in `OperationCLIDriver`'s actual constructed tree is exactly one of: `RootCommand`, `NounNode<Rep>`, `ToolNode<Rep>`, or ArgumentParser's built-in `HelpCommand` — and all four throw unconditionally from `run()`. Every leaf that *could* return non-throwing already conforms to `OperationCommand` (the macro-generated `Command`, or `FallbackOperationCommand`), so it's caught by `dispatch(command:)`'s `guard let opCommand = command as? any OperationCommand` and never even calls `runNonOperationCommand`. `OperationCLIDriver`'s public API (`init(tool:)`/`init(tools:)`) gives no way to inject an arbitrary custom `ParsableCommand` into the tree to manufacture a non-throwing leaf.

    Verified empirically too (scratch test, since removed): drove the real driver with `["note"]` (bare noun, no verb), `["help"]` (literal help subcommand), `["note", "help"]`, and `[]` (bare root). All four returned `exitCode == 0` with non-empty help text — i.e. all went through `runNonOperationCommand`'s `catch` → `errorResult(for:)`, never its `return CLIResult(output: "", exitCode: 0)` success line.

    Conclusion: the literal success return (`CLIResult(output: "", exitCode: 0)`, originally-uncovered lines 127-128) is genuinely unreachable through `OperationCLIDriver.run(arguments:)`'s public API — following the same pattern the earlier ^p02890h task established for `CLIRegistryBuilder`'s `.emptyTool` branch. No test was forced for it, and production code was not modified.

    However, one part of the original gap *was* legitimately fixable, same as that earlier task fixed its `.duplicateOperation` half: originally-uncovered line 124 (the async branch's `try await asyncCommand.run()` call) had never been entered by any existing test, since it requires a non-`OperationCommand` `AsyncParsableCommand` node — only `RootCommand` qualifies, reached bare with zero arguments (`arguments: []`). Added `CLIDriverBareRootTests.noArgumentsAtAllShowsRootHelpWithASuccessExitCode()` to Tests/OperationsCLITests/CLIDriverTests.swift, asserting `exitCode == 0` and output containing "note" (the root help listing). This is a real, non-vacuous exercise of the async branch (confirmed by an adversarial double-check agent, verdict PASS, no findings) — it still throws internally (as it must, per the above), so line 124 becomes covered but 127-128 remain genuinely dead.

    Verification: `rm -rf .build && swift build` — clean, 0 warnings. `swift test` — 168 tests across 4 targets (72 + 30 + 44 + 22), 0 failures. Diff is scoped to Tests/OperationsCLITests/CLIDriverTests.swift only (29 lines added, one new test/suite); Sources/OperationsCLI/OperationCLIDriver.swift is untouched.

    Leaving task in `doing` per process — not moving to review myself.
  timestamp: 2026-07-03T14:40:15.329262+00:00
position_column: doing
position_ordinal: '80'
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