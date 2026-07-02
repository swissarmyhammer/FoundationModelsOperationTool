---
depends_on:
- 01KWHQCVGNFHVT0ZKEDAG802RR
position_column: todo
position_ordinal: '8380'
title: 'Schema fusion: flat-union GenerationSchema from [AnyOperation]'
---
## What
`Sources/Operations/SchemaFusion.swift`: build the DECIDED flat-union `GenerationSchema` (plan.md "Schema fusion — DECIDED") from `[AnyOperation<Context>]` via `DynamicGenerationSchema`:
- required `op` property as string enum via `DynamicGenerationSchema(name:description:anyOf: [String])` of all opStrings
- union of every operation's fields as declared properties, ALL optional (`Property(..., isOptional: true)`)
- shared-field dedup by name; collision policy: first description wins
- a parameter literally named `op` (post-normalization) is a fusion-time error
- deterministic property order (op first, then fields sorted by first-seen op order then name)
Finish with `GenerationSchema(root:dependencies:)`.

## Acceptance Criteria
- [ ] Fusing 3 fixture ops yields a schema whose op enum has exactly the 3 op strings and whose properties are the field union with everything but `op` optional
- [ ] Same input array ⇒ byte-identical property ordering across runs
- [ ] Fusion throws a descriptive error on a reserved-`op` parameter

## Tests
- [ ] `Tests/OperationsTests/SchemaFusionTests.swift` — structural assertions (property names present, op-enum membership, optionality, deterministic order, shared fields appear once, first-description-wins); NOT byte-level snapshots of Apple's encoding
- [ ] Run `swift test --filter SchemaFusionTests`; all pass (requires macOS 26 runtime)

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.