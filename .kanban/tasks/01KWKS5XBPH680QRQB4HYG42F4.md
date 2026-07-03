---
position_column: todo
position_ordinal: '8580'
title: Add test for SchemaFusion's .number (Double) type mapping
---
Sources/Operations/SchemaFusion.swift:161-174 (specifically line 168)

Coverage: 98.6% (70/71 lines)

Uncovered line: 168, the `.number` case of `dynamicSchema(for:)`:

```swift
private func dynamicSchema(for type: ParamType) -> DynamicGenerationSchema {
    switch type {
    case .string: ...
    case .integer: ...
    case .number:
        return DynamicGenerationSchema(type: Double.self)
    case .boolean: ...
    case .array(let element): ...
    }
}
```

No `SchemaFusionTests` fixture includes a `.number`/`Double`-typed parameter, so this branch is never exercised — meaning fused-schema correctness for Double-typed fields is unverified. Add a fixture operation with a `Double` parameter and assert the fused `GenerationSchema`'s rendered JSON constrains it as a number.