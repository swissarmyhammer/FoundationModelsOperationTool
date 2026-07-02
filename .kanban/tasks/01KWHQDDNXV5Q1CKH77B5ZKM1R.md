---
comments:
- actor: wballard
  id: 01kwhxcmra1g3jm644tvyaqqvy
  text: "Implemented via TDD. \n\n**What was built:**\n- `Sources/Operations/Operations.swift`: real `@attached(extension, conformances: OperationDefinition, names: ...)` declaration for `@Operation(verb:noun:description:)`, plus new `@attached(peer) @OperationParam(short:aliases:allowedValues:)` marker macro declaration.\n- `Sources/OperationsMacros/OperationsMacros.swift`: `OperationMacro: ExtensionMacro` synthesizes an `extension X: OperationDefinition { static let verb/noun/operationDescription; static let parameterMetadata: [ParamMeta] }` by walking stored properties. Type mapping (String/Int/Double/Float/Bool, `[T]`, `Optional` ⇒ not required), description from literal `@Guide(description:)` else `///` doc-comment trivia else `\"\"`, `allowedValues` from `@OperationParam(allowedValues:)` else a recognized literal `@Guide(.anyOf([...]))`, short/aliases from `@OperationParam`. Diagnostics (all `.error` severity): non-struct target, empty/missing `verb`/`noun` literal, reserved parameter name `op` (normalizes lowercase + strips `_`/`-`, so `_Op`/`O-P` are caught too), unsupported field type. `OperationParamMacro: PeerMacro` expands to nothing (pure marker read by `OperationMacro`). Command-emission (ArgumentParser leaf) is explicitly out of scope per the task description — left to the follow-on task.\n- `Package.swift`: added `SwiftSyntax`/`SwiftSyntaxBuilder`/`SwiftSyntaxMacroExpansion`/`SwiftSyntaxMacrosTestSupport` deps to `OperationsMacrosTests`.\n- Tests: `Tests/OperationsMacrosTests/OperationMacroTests.swift` — 14 `assertMacroExpansion` fixtures (simple op, optional/array fields, Int/Double/Bool/required-array types, unit struct, `@OperationParam` short/aliases, `@Guide(.anyOf(...))`, doc-comment fallback, reserved-`op` + normalizes-to-`op` diagnostics, unsupported-type diagnostic, empty verb/noun diagnostics, non-struct diagnostic). `Tests/OperationsTests/OperationMacroIntegrationTests.swift` — a real `@Generable @Operation(...)` struct compiled end-to-end (not simulated) proving conformance, parameterMetadata, and `AnyOperation` dispatch all work under the actual compiler.\n\n**Process notes:** Wrote fixtures first against the extension-macro stub (which returned `[]`), watched them fail, then implemented. Diagnostic line/column expectations were calibrated against real `assertMacroExpansion` output (3 off-by-one/line guesses corrected) rather than hand-computed — standard for macro snapshot tests. An adversarial double-check pass flagged a real coverage gap (no fixture exercised Int/Double/Bool/required-array types); added `numericBooleanAndRequiredArrayFieldsMapToTheirParamTypes` to close it.\n\n**Verification:** `swift build` — 0 errors, 0 warnings. `swift test` — 28/28 tests pass across all three test targets (13 OperationsTests incl. 3 new integration tests, 14 OperationsMacrosTests, 1 OperationsCLITests), 0 failures, 0 warnings.\n\nLeaving task in `doing` for review per the implement workflow."
  timestamp: 2026-07-02T17:17:56.362066+00:00
depends_on:
- 01KWHQCVGNFHVT0ZKEDAG802RR
position_column: doing
position_ordinal: '80'
title: '@Operation macro (metadata): conformance, ParamMeta synthesis, diagnostics'
---
## What
In `Sources/OperationsMacros/` (impl) + `Sources/Operations/` (declarations): attached extension+member macro `@Operation(verb:noun:description:)` and marker attribute `@OperationParam(short:aliases:)` — the metadata half only (the nested ArgumentParser `Command` emission is a separate follow-on task).
Emits on the annotated struct:
- `OperationDefinition` conformance with `static verb/noun/operationDescription`
- `static parameterMetadata: [ParamMeta]` from stored properties: type mapping (String/Int/Double/Bool/[T], `Optional` ⇒ not required), description from literal `@Guide(description:)` argument (fallback: doc-comment `///` trivia), short/aliases from `@OperationParam`, allowedValues from `@OperationParam` or a recognized literal `@Guide(.anyOf([...]))` — all other `@Guide` constraint forms ignored in ParamMeta (left to Apple's schema)
Diagnostics: unsupported field types, missing verb/noun, reserved parameter name `op` (including names that normalize to `op`).

## Acceptance Criteria
- [x] A `@Generable @Operation(...)` struct gains OperationDefinition conformance and a correct parameterMetadata table
- [x] A field documented only by `///` doc comment (no `@Guide`) gets that text as its ParamMeta description
- [x] Reserved-name `op` field produces a compile-time diagnostic

## Tests
- [x] `Tests/OperationsMacrosTests/OperationMacroTests.swift` — `assertMacroExpansion` fixtures: simple op; optional/array fields; unit struct (no fields); `@OperationParam` short/aliases; `@Guide` with constraint args; **doc-comment-trivia description fallback (no @Guide)**; reserved-`op` diagnostic; unsupported-type diagnostic
- [x] Run `swift test --filter OperationMacroTests`; all pass

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Implementation Notes (2026-07-02)

Implemented `OperationMacro: ExtensionMacro` and `OperationParamMacro: PeerMacro` in `Sources/OperationsMacros/OperationsMacros.swift`, with real macro declarations (replacing the stubs) in `Sources/Operations/Operations.swift`. Also added a required end-to-end integration test (`Tests/OperationsTests/OperationMacroIntegrationTests.swift`) applying `@Operation`/`@OperationParam`/`@Guide`/`@Generable` together and compiling for real, plus an extra fixture covering Int/Double/Bool/required-array type mapping (found missing by adversarial review). Command-emission (ArgumentParser leaf) intentionally deferred to the follow-on task per the "What" section above.

Final verification: `swift build` 0 errors/0 warnings; `swift test` 28/28 passing across all three test targets, 0 warnings.