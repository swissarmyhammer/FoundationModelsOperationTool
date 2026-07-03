---
position_column: todo
position_ordinal: 8c80
title: Add tests for @Operation macro's unrecognized-syntax-shape fallback branches
---
Sources/OperationsMacros/OperationsMacros.swift:76, 83-88, 179, 293, 431

Coverage: 94.7% (397/419 lines)

Several "recognizer returns nil/[] for an unrecognized syntax shape" branches are untested, all in the same file and best tackled together:

- Line 76 — `ExprSyntax.plainStringLiteralValue` returns `nil` for a non-literal or interpolated string expression (e.g. `@Operation(verb: "\(dynamicValue)")`). Untested: what diagnostic/behavior results from a non-literal `verb`/`noun` argument.
- Lines 83-88 — `DeclModifierSyntax.isNeededAccessLevelModifier`'s `default: return false` branch. Untested: macro expansion on a struct with no `public` modifier (internal-access `@Operation` struct) — verify the generated extension's access level is correct in that case.
- Line 179 — `primitiveParamTypeExprText` returns `nil` for a type that's neither an array nor a plain identifier type (e.g. a dictionary type `[String: Int]`, tuple, or `some Protocol`). Untested: the unsupported-type diagnostic for a structurally unusual (not just unrecognized-identifier) type.
- Line 293 — `anyOfAllowedValues` returns `nil` when a `@Guide` attribute's argument isn't a recognized `.anyOf([...])` call (e.g. `@Guide(.range(0...10))` or a plain description-only `@Guide`). Untested: that `allowedValues` is correctly omitted (not mis-parsed) for other `@Guide` constraint kinds.
- Line 431 — `OperationMacro.expansion` returns `[]` when `node.arguments` isn't `.argumentList` at all. Likely defensive/hard to construct via real Swift source (valid `@Operation(...)` invocations always produce `.argumentList`) — lower priority than the others; investigate whether it's reachable before writing a test.

Add `assertMacroExpansion`/diagnostic-fixture tests for each reachable branch (76, 83-88, 179, 293); confirm whether 431 is reachable through normal source before deciding whether to test or leave as defensive/unreachable.