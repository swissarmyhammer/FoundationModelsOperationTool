---
comments:
- actor: wballard
  id: 01kwkwx1v4a980qyhbb4hcrws0
  text: |-
    Implemented. Added two tests to Tests/OperationsTests/OperationToolTests.swift, in a new "MARK: - resolveParameters: non-structure top-level content" section inside the existing OperationToolTests suite (matching the file's convention of testing OperationResolver's other internal methods, e.g. matchOpString, directly via @testable import):

    - resolveParametersOnATopLevelScalarStringReportsEveryRequiredParameterMissing — GeneratedContent(kind: .string(...))
    - resolveParametersOnATopLevelArrayReportsEveryRequiredParameterMissing — GeneratedContent(kind: .array([...]))

    Both assert missingRequired == ["title"] (the required param) and content == GeneratedContent(kind: .structure(properties: [:], orderedKeys: [])), proving the else branch (lines 158-159 in OperationResolver.swift) degrades gracefully rather than crashing.

    No production code touched (Sources/ unchanged) — verified via git diff.

    Verification: rm -rf .build && swift build — clean, zero warnings. swift test (fresh, all 4 targets) — 149 tests total (70+30+27+22 across suites), all passed, zero failures.

    Adversarial double-check (subagent a2c96c5cfd1ca801e): PASS. Confirmed scope is test-only, confirmed both tests genuinely exercise the non-discriminating else branch (traced matchingKey to show it deterministically returns nil for any non-structure kind), confirmed assertions would catch a regression, confirmed string+array is sufficient (the branch doesn't discriminate between non-structure kinds, so .number/.bool/.null would be redundant not additive), confirmed style matches file conventions.

    Leaving in doing for review per /implement workflow.
  timestamp: 2026-07-03T11:47:54.340664+00:00
position_column: done
position_ordinal: 8c80
title: Add test for OperationResolver.resolveParameters on non-structure GeneratedContent
---
Sources/Operations/OperationResolver.swift:153-159

Coverage: 94.8% (73/77 lines)

Uncovered lines: 158-159, inside `resolveParameters(_:matching:)`:

```swift
internal func resolveParameters(_ content: GeneratedContent, matching parameters: [ParamMeta]) -> ParameterResolution {
    let rawProperties: [String: GeneratedContent]
    if case let .structure(properties, _) = content.kind {
        rawProperties = properties
    } else {
        rawProperties = [:]
    }
    ...
}
```

No test passes a top-level `GeneratedContent` whose `.kind` is not `.structure` (e.g. a bare scalar, array, or null at the top level instead of an object). Add a test asserting `resolveParameters` degrades gracefully — every parameter reported missing (if required) rather than crashing — when given non-structure content.