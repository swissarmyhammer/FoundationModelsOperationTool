---
depends_on:
- 01KWHQCDGHM2HK9ZG4E49DEZ7S
position_column: todo
position_ordinal: '8180'
title: Core metadata types + OperationDefinition protocol + AnyOperation erasure
---
## What
In `Sources/Operations/`: the macro-free core per plan.md "Declaring an operation" / "Type erasure and registry".
- `ParamMeta.swift`: `ParamType` enum (string, integer, number, boolean, array(of:)) and `ParamMeta` struct (name, type, required, description, short: Character?, aliases: [String], allowedValues: [String]?), Sendable.
- `OperationDefinition.swift`: `protocol OperationDefinition: Generable, Sendable` with `associatedtype Context: Sendable`, `associatedtype Output: Encodable & Sendable`, statics `verb`, `noun`, `operationDescription`, `parameterMetadata`, `opString` (default extension: `"\(verb) \(noun)"`), and `func execute(in: Context) async throws -> Output`.
- `AnyOperation.swift`: `struct AnyOperation<Context: Sendable>: Sendable` capturing verb/noun/description/parameters and a `run: @Sendable (GeneratedContent, Context) async throws -> String` that constructs the typed op via `O(content)` and JSON-encodes the Output.
- `OperationError.swift`: error enum (unknownOperation(valid: [String]), missingRequired([String]), decodingFailed, executionFailed).
Hand-conform a fixture op in the test target (no macro yet) to prove the manual escape hatch.

## Acceptance Criteria
- [ ] `AnyOperation(FixtureOp.self)` compiles with Context type inference and runs end-to-end against a fake context
- [ ] `opString` default renders "verb noun"
- [ ] Output JSON from `run` is deterministic (sorted keys) for test stability

## Tests
- [ ] `Tests/OperationsTests/CoreTypesTests.swift` — opString default; ParamMeta construction; AnyOperation happy path returns expected JSON; execute-throws path surfaces `OperationError.executionFailed`
- [ ] Run `swift test --filter CoreTypesTests`; all pass

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.