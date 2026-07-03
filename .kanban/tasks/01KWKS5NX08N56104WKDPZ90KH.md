---
position_column: todo
position_ordinal: '8380'
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