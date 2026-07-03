---
position_column: todo
position_ordinal: 8a80
title: Add tests for FallbackPayloadBuilder's number and array parameter conversion
---
Sources/OperationsCLI/FallbackOperationCommand.swift:160-212

Coverage: 75.2% (97/129 lines)

Uncovered lines: 167 (`.number` case in `convertedScalarOrArray`), 169 (`.array` case in `convertedScalarOrArray`), and the entire `convertedArray` function body (189-202: `.string`/`.integer`/`.number`/`.boolean`/`.array` cases) plus `convertedIfEveryElementParses` (209-212):

```swift
private static func convertedScalarOrArray(rawValues: [String], type: ParamType) -> (any ConvertibleToGeneratedContent)? {
    switch type {
    ...
    case .number:
        return convertedIfLastElementParses(rawValues: rawValues, using: Double.init)   // 167
    case .array(let element):
        return convertedArray(rawValues: rawValues, elementType: element)               // 169
    ...
    }
}

private static func convertedArray(rawValues: [String], elementType: ParamType) -> (any ConvertibleToGeneratedContent)? {
    switch elementType {
    case .string: return rawValues
    case .integer: return convertedIfEveryElementParses(rawValues: rawValues, using: Int.init)
    case .number: return convertedIfEveryElementParses(rawValues: rawValues, using: Double.init)
    case .boolean: return convertedIfEveryElementParses(rawValues: rawValues, using: { Bool($0) })
    case .array: return nil
    }
}
```

No test exercises a macro-less fallback leaf's `Double`-typed scalar parameter, nor ANY array-typed parameter (`[String]`, `[Int]`, `[Double]`, `[Bool]`, or nested-array-returns-nil). This is the largest single gap in the file — array-parameter CLI conversion for the manual escape hatch is entirely unverified. Add CLI-driver round-trip tests for a macro-less fixture operation with a `Double` parameter and with `[String]`/`[Int]`/`[Bool]` array parameters (repeated flag occurrences), plus a test asserting a nested-array parameter type converts to `nil` (silently omitted, per the function's documented contract).