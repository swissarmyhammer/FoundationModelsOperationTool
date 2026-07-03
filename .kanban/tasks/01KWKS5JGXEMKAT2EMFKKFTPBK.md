---
comments:
- actor: wballard
  id: 01kwktq3bqqrtazp437rdhbfvn
  text: |-
    Added two unit tests to Tests/OperationsTests/CoreTypesTests.swift (new "OperationError.description" MARK section) asserting exact description text for OperationError.decodingFailed and .encodingFailed, per the coverage gap.

    While self-checking against the local /review engine (per task guidance), it flagged that OperationError.executionFailed's description also lacked a direct string-equality test anywhere in the suite (confirmed by grep — the task description said it was "covered", but that appears to only mean the .executionFailed case itself is exercised via Equatable comparison in anyOperationRunExecuteThrowsSurfacesOperationErrorExecutionFailed, not that .description was ever called on it). Added a third test, operationErrorExecutionFailedDescriptionReturnsExecutionFailureMessage, to close that gap too and keep the new MARK section consistent across all three description-only cases (decodingFailed/encodingFailed/executionFailed — unknownOperation and missingRequired are already covered indirectly via OperationToolTests' corrective-message assertions).

    No production code changed (OperationError.swift untouched).

    Verification:
    - swift build (clean, after `swift package clean`): Build complete, 0 warnings/errors.
    - swift test (clean, full suite): all 4 test-run groups green — 62+30+27+22 = 141 tests, 0 failures, 0 warnings.
    - Local /review engine (review working): 0 findings after adding the third test.

    Leaving in doing for /review.
  timestamp: 2026-07-03T11:09:42.135155+00:00
position_column: done
position_ordinal: 8a80
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