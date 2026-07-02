---
depends_on:
- 01KWHQDDNXV5Q1CKH77B5ZKM1R
position_column: todo
position_ordinal: '8880'
title: '@Operation macro (CLI leaf): nested AsyncParsableCommand emission'
---
## What
Extend the `@Operation` macro in `Sources/OperationsMacros/` to additionally emit a nested `Command: AsyncParsableCommand` (ArgumentParser leaf) on the annotated struct, per plan.md "Dual-use CLI":
- `@Option`/`@Flag`/`@Argument` per stored property: `Bool` ⇒ presence flag, arrays ⇒ repeatable option, `Optional` ⇒ non-required option; help text from `@Guide` descriptions; shorts/aliases from `@OperationParam`
- `CommandConfiguration(commandName: verb, abstract: description)`
- `run()` serializing parsed values into the canonical payload (`op` + fields, via `GeneratedContent(json:)`) and dispatching through the shared `AnyOperation.run` execution path — the same payload shape the model sends

## Acceptance Criteria
- [ ] The plan.md `AddNote` example compiles verbatim with `@Generable @Operation(...)` and exposes a working nested `Command`
- [ ] Generated `Command` maps Bool⇒Flag, `[String]`⇒repeatable Option, `String?`⇒optional Option, required String⇒required Option
- [ ] `Command.run()` produces a payload byte-identical in shape to the model path for the same values

## Tests
- [ ] `Tests/OperationsMacrosTests/CommandEmissionTests.swift` — `assertMacroExpansion` fixtures for generated Command shape (flag vs option vs repeatable mapping, config values); a compile-and-parse test that runs `AddNote.Command.parse(["--title", "Hi"])` and asserts the serialized payload
- [ ] Run `swift test --filter CommandEmissionTests`; all pass

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.