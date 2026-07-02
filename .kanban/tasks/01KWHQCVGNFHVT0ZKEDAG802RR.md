---
comments:
- actor: wballard
  id: 01kwhtzv0z747m3r5nw0ttaapx
  text: |-
    Implemented via TDD:
    - Tests/OperationsTests/CoreTypesTests.swift written first (RED: confirmed compile failure — missing ParamMeta/OperationDefinition types), then made GREEN.
    - Sources/Operations/ParamMeta.swift — ParamType (string/integer/number/boolean/indirect array(of:)) + ParamMeta struct (name, type, required, description, short: Character?, aliases, allowedValues), both Sendable/Equatable.
    - Sources/Operations/OperationDefinition.swift — protocol OperationDefinition: Generable, Sendable with associatedtype Context: Sendable, associatedtype Output: Encodable & Sendable, verb/noun/operationDescription/parameterMetadata statics, opString (default extension "\(verb) \(noun)"), execute(in:) async throws.
    - Sources/Operations/AnyOperation.swift — struct AnyOperation<Context: Sendable>: Sendable erasing verb/noun/description/parameters plus an internal `run` closure that decodes GeneratedContent via O(content), calls execute(in:), and JSON-encodes Output with JSONEncoder.outputFormatting = [.sortedKeys] for deterministic output. init<O: OperationDefinition>(_:) where O.Context == Context infers Context from O, matching AnyOperation(FixtureOp.self) usage.
    - Sources/Operations/OperationError.swift — enum unknownOperation(valid: [String]), missingRequired([String]), decodingFailed, executionFailed (last two carry no associated data per task spec).
    - Test fixture (private FixtureOperation in CoreTypesTests.swift) hand-conforms to OperationDefinition/Generable with no macro — proves the manual escape hatch. Required reading the live FoundationModels.swiftinterface (macOS 27 SDK, Xcode-beta) to get exact Generable/GeneratedContent API shapes (init(_ content:) throws, value(_:forProperty:), GeneratedContent(properties:), GeneratedContent(kind: .structure(...))) since this is pre-release/system-framework API.

    Verification: swift build clean (zero warnings), swift test full suite green (11 tests: 9 in OperationsTests incl. 7 new CoreTypesTests + 2 existing placeholders, 1 each in OperationsMacrosTests/OperationsCLITests). Adversarial double-check ran REVISE with one minor doc-comment completeness nit (AnyOperation.run's doc didn't mention JSON-encode-failure also maps to .decodingFailed) — fixed, re-verified green after the fix.

    Leaving task in doing for review per /implement workflow.
  timestamp: 2026-07-02T16:35:59.647728+00:00
depends_on:
- 01KWHQCDGHM2HK9ZG4E49DEZ7S
position_column: doing
position_ordinal: '80'
title: Core metadata types + OperationDefinition protocol + AnyOperation erasure
---
## What\nIn `Sources/Operations/`: the macro-free core per plan.md \"Declaring an operation\" / \"Type erasure and registry\".\n- `ParamMeta.swift`: `ParamType` enum (string, integer, number, boolean, array(of:)) and `ParamMeta` struct (name, type, required, description, short: Character?, aliases: [String], allowedValues: [String]?), Sendable.\n- `OperationDefinition.swift`: `protocol OperationDefinition: Generable, Sendable` with `associatedtype Context: Sendable`, `associatedtype Output: Encodable & Sendable`, statics `verb`, `noun`, `operationDescription`, `parameterMetadata`, `opString` (default extension: `\"\\(verb) \\(noun)\"`), and `func execute(in: Context) async throws -> Output`.\n- `AnyOperation.swift`: `struct AnyOperation<Context: Sendable>: Sendable` capturing verb/noun/description/parameters and a `run: @Sendable (GeneratedContent, Context) async throws -> String` that constructs the typed op via `O(content)` and JSON-encodes the Output.\n- `OperationError.swift`: error enum (unknownOperation(valid: [String]), missingRequired([String]), decodingFailed, executionFailed).\nHand-conform a fixture op in the test target (no macro yet) to prove the manual escape hatch.\n\n## Acceptance Criteria\n- [x] `AnyOperation(FixtureOp.self)` compiles with Context type inference and runs end-to-end against a fake context\n- [x] `opString` default renders \"verb noun\"\n- [x] Output JSON from `run` is deterministic (sorted keys) for test stability\n\n## Tests\n- [x] `Tests/OperationsTests/CoreTypesTests.swift` — opString default; ParamMeta construction; AnyOperation happy path returns expected JSON; execute-throws path surfaces `OperationError.executionFailed`\n- [x] Run `swift test --filter CoreTypesTests`; all pass\n\n## Workflow\n- Use `/tdd` — write failing tests first, then implement to make them pass.