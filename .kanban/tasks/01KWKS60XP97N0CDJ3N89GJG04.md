---
comments:
- actor: wballard
  id: 01kwkzny90cmpj25w2pv4x1ygm
  text: |-
    Verified exact description strings against Sources/OperationsCLI/CLIRegistryBuilder.swift lines 24-34, then added a new @Suite `OperationCLIDriverErrorDescriptionTests` in Tests/OperationsCLITests/CLIDriverTests.swift (appended after the existing `CLIDriverErrorTests` suite) covering all three cases: `.duplicateToolName("x")`, `.emptyTool("x")`, `.duplicateOperation(tool: "x", opString: "y")`, each asserting the exact description text via `#expect`. No production code was touched (git diff confirms CLIRegistryBuilder.swift is unchanged).

    Clean build (`rm -rf .build && swift build`): 0 warnings, exit 0.
    `swift test`: all 4 test-target suites green — 72+30+30+22 tests, 0 failures, 0 warnings. New suite `OperationCLIDriverErrorDescriptionTests` (3 tests) passes.

    Kicked off adversarial double-check agent to verify string-for-string accuracy and no production-code drift before handoff.
  timestamp: 2026-07-03T12:36:27.040310+00:00
- actor: wballard
  id: 01kwkzpvrfgnd92m2eh54m7str
  text: |-
    Adversarial double-check verdict: PASS. Independently confirmed (1) all three expected description strings match CLIRegistryBuilder.swift character-for-character, (2) CLIRegistryBuilder.swift has zero diff (only the test file changed), (3) style/accessibility consistent with the file's existing @Suite/@Test/#expect patterns and @testable import, (4) all three enum cases covered exactly once, (5) re-ran `swift test --filter OperationCLIDriverErrorDescriptionTests` fresh — 3/3 pass, exit 0.

    Work is done and green. Leaving task in doing for /review.
  timestamp: 2026-07-03T12:36:57.231917+00:00
position_column: doing
position_ordinal: '80'
title: Add tests for OperationCLIDriverError.description
---
Sources/OperationsCLI/CLIRegistryBuilder.swift:22-35

Coverage: 90.6% (126/139 lines)

Uncovered lines: 24-34, the entire `CustomStringConvertible.description` switch:

```swift
public var description: String {
    switch self {
    case let .duplicateToolName(name):
        return "duplicate tool name '\(name)': every tool passed to OperationCLIDriver must have a unique name"
    case let .emptyTool(name):
        return "tool '\(name)' has no operations: OperationCLIDriver requires at least one operation per tool"
    case let .duplicateOperation(tool, opString):
        return "tool '\(tool)' declares '\(opString)' more than once: every operation's verb/noun pair must be unique within a tool"
    }
}
```

None of the three `OperationCLIDriverError` cases' human-readable descriptions are tested. Add unit tests asserting the exact description text for `.duplicateToolName`, `.emptyTool`, and `.duplicateOperation`.