---
position_column: todo
position_ordinal: '8680'
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