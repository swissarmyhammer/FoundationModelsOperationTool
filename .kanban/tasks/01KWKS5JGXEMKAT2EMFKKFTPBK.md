---
position_column: todo
position_ordinal: '8180'
title: Add tests for OperationError.description's decodingFailed/encodingFailed cases
---
Sources/Operations/OperationError.swift:48,50

Coverage: 85.7% (12/14 lines)

Uncovered lines: 48 (`.decodingFailed` case), 50 (`.encodingFailed` case) of the `description` switch:

```swift
public var description: String {
    switch self {
    ...
    case .decodingFailed:
        return "Could not parse the given parameter values for this operation."
    case .encodingFailed:
        return "Could not encode this operation's result."
    ...
    }
}
```

`.unknownOperation`, `.missingRequired`, and `.executionFailed`'s description branches are covered; `.decodingFailed`/`.encodingFailed` are not. Add unit tests asserting the exact description text for both cases.