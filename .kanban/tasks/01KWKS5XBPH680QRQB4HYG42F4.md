---
comments:
- actor: wballard
  id: 01kwkz68e3130g2y2j5y5s9gp8
  text: |-
    Added FixtureRateItem (a .number/Double parameter "score") plus a new test numberParameterIsRenderedAsNumberType() to Tests/OperationsTests/SchemaFusionTests.swift, following the file's existing fixture/fusedJSONObject conventions. Confirmed via debug print that a Double field renders as {"type": "number", ...} in the fused JSON schema. Verified TDD RED by temporarily swapping SchemaFusion.swift's .number case to Int.self — the new test failed with the expected "integer" vs "number" mismatch — then reverted (SchemaFusion.swift diff is empty in the final state; only the test file changed, per the coverage-backfill constraint).

    Clean build (`rm -rf .build && swift build`) and `swift test`: 0 errors, 0 warnings, 151 tests across 4 targets all passing, including numberParameterIsRenderedAsNumberType(). Local /review engine: 0 findings. Adversarial double-check agent: PASS.

    Leaving task in doing for /review.
  timestamp: 2026-07-03T12:27:53.155163+00:00
position_column: doing
position_ordinal: '80'
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