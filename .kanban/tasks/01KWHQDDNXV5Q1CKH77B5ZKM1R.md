---
depends_on:
- 01KWHQCVGNFHVT0ZKEDAG802RR
position_column: todo
position_ordinal: '8280'
title: '@Operation macro (metadata): conformance, ParamMeta synthesis, diagnostics'
---
## What
In `Sources/OperationsMacros/` (impl) + `Sources/Operations/` (declarations): attached extension+member macro `@Operation(verb:noun:description:)` and marker attribute `@OperationParam(short:aliases:)` — the metadata half only (the nested ArgumentParser `Command` emission is a separate follow-on task).
Emits on the annotated struct:
- `OperationDefinition` conformance with `static verb/noun/operationDescription`
- `static parameterMetadata: [ParamMeta]` from stored properties: type mapping (String/Int/Double/Bool/[T], `Optional` ⇒ not required), description from literal `@Guide(description:)` argument (fallback: doc-comment `///` trivia), short/aliases from `@OperationParam`, allowedValues from `@OperationParam` or a recognized literal `@Guide(.anyOf([...]))` — all other `@Guide` constraint forms ignored in ParamMeta (left to Apple's schema)
Diagnostics: unsupported field types, missing verb/noun, reserved parameter name `op` (including names that normalize to `op`).

## Acceptance Criteria
- [ ] A `@Generable @Operation(...)` struct gains OperationDefinition conformance and a correct parameterMetadata table
- [ ] A field documented only by `///` doc comment (no `@Guide`) gets that text as its ParamMeta description
- [ ] Reserved-name `op` field produces a compile-time diagnostic

## Tests
- [ ] `Tests/OperationsMacrosTests/OperationMacroTests.swift` — `assertMacroExpansion` fixtures: simple op; optional/array fields; unit struct (no fields); `@OperationParam` short/aliases; `@Guide` with constraint args; **doc-comment-trivia description fallback (no @Guide)**; reserved-`op` diagnostic; unsupported-type diagnostic
- [ ] Run `swift test --filter OperationMacroTests`; all pass

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.