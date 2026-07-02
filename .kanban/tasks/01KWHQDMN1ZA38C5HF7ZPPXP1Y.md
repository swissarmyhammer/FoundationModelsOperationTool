---
comments:
- actor: wballard
  id: 01kwj64q7h545gjkmhah0nh2nf
  text: |-
    Implemented via TDD.

    - `Sources/Operations/SchemaFusion.swift` (new): `SchemaFusion.fuse(_:name:description:)` builds the flat-union `GenerationSchema` from `[AnyOperation<Context>]` using `DynamicGenerationSchema` — required `op` property as a string enum (`anyOf: [String]` of every `opString`), plus the all-optional union of every operation's fields, finishing with `GenerationSchema(root:dependencies:)`. Shared-field dedup by name (first description wins). A parameter whose name normalizes to `"op"` (lowercased, `_`/`-` stripped — mirrors `OperationsMacros`' `normalizedForReservedCheck`, duplicated here since that helper lives in the compiler-plugin target) throws `SchemaFusionError.reservedParameterName`, which is `CustomStringConvertible` for a descriptive message. `dynamicSchema(for:)` maps each `ParamType` case to a `DynamicGenerationSchema` (string/integer/number/boolean/array recursively). Deliberately does not read `ParamMeta.allowedValues` in the fused schema — documented as an intentional scope boundary (same enum-enforcement bug that ruled out discriminated `anyOf` per plan.md applies equally there; validated at dispatch instead).
    - `Sources/Operations/AnyOperation.swift`: added a computed `opString` property (`"\(verb) \(noun)"`) so schema fusion (and later dispatch) doesn't need to re-derive it or duplicate storage.
    - `Tests/OperationsTests/SchemaFusionTests.swift` (new, 9 tests): structural JSON assertions (via `JSONSerialization`, not byte snapshots) — op-enum membership, all-but-`op` optionality, field-union membership, first-description-wins on the shared `id` field, deterministic `x-order`, byte-identical re-encoding across two `fuse` calls on the same input, and both reserved-`op` cases (literal `"op"` and normalized `"_OP"`).

    Research note: confirmed the exact `DynamicGenerationSchema`/`GenerationSchema` API surface (including the `anyOf: [String]` overload and the `Codable` JSON shape — `properties`/`required`/`x-order`/`enum` keys) against the installed macOS 26 SDK's `.swiftinterface` and a standalone probe script before writing any code, since this isn't in training data.

    Adversarial double-check (round 1) caught a real spec gap: the task's "fields sorted by first-seen op order then name" wording implies a compound sort key, but the first implementation only did encounter order (no alphabetical tie-break within the same first-seen operation) — the test fixture's own data (`title` declared before `tags`, non-alphabetical) proved it wasn't accidentally masked. Fixed by sorting unique fields by `(firstSeenOpIndex, name)` via a small `FirstSeenField` helper type (avoids force-unwraps; the sort key is a genuine strict total order since parameter names are unique, so it's deterministic regardless of `Dictionary.values`' unspecified iteration order). Updated the ordering test's expectation accordingly. Round 2 double-check: PASS.

    Verification: `swift build` and `swift test` both clean — 22 tests in OperationsTests (13 pre-existing + 9 new), 15 in OperationsMacrosTests, 1 CLI placeholder, all passing, 0 warnings, 0 failures.

    Leaving in `doing` for review.
  timestamp: 2026-07-02T19:50:53.937969+00:00
depends_on:
- 01KWHQCVGNFHVT0ZKEDAG802RR
position_column: done
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