---
comments:
- actor: wballard
  id: 01kwj8k0pzfnbj0pxkv2reex16
  text: |-
    Implemented via TDD. Summary of design decisions (also documented in code):

    1. **Mapping** (Sources/OperationsMacros/OperationsMacros.swift): Bool -> `@Flag` (default false); array-of-primitive -> repeatable `@Option` defaulting to `[]` (single level only — nested arrays like `[[String]]` get a `ParamMeta` entry but no `Command` field, silently, since ArgumentParser needs `ExpressibleByArgument` element types; pinned by `nestedArrayFieldGetsParamMetaEntryButNoCommandField` in CommandEmissionTests.swift); Optional scalar -> non-required `@Option` (`T?`); everything else -> required `@Option`.

    2. **Payload construction deviates from plan.md's literal `GeneratedContent(json:)` text**: `Command.operationPayload()` builds a `GeneratedContent` via `GeneratedContent(properties: [(String, any ConvertibleToGeneratedContent)], uniquingKeysWith:)` instead. Reason: round-tripping through `JSONSerialization` + `GeneratedContent(json:)` requires an explicit `import Foundation` in every file that applies `@Operation` — confirmed by a real compile failure ("cannot find 'JSONSerialization' in scope") in the existing `OperationMacroIntegrationTests.swift` fixture, which only imports `FoundationModels`. The `properties:` initializer needs no extra import (every `@Operation`-supported type already conforms to `ConvertibleToGeneratedContent` via `Generable`/`Array`), and achieves the identical net effect (the canonical `op` + fields payload). Net shape is unaffected; `CommandCompileAndParseTests` in the same file round-trips a parsed `Command`'s payload back through `AddNoteCommandFixture(_:)` to prove it.

    3. **`Command.run()` does not yet dispatch through `AnyOperation.run`** — it's `mutating func run() async throws { print(operationPayload().jsonString) }`. This task has no dependency on `OperationTool`/`OperationCLIDriver` (tasks ^rnvamra / ^rsstrtt), so there's no way to obtain a live `Context` instance here. Wiring `run()` to actually execute through `AnyOperation.run` is explicitly task ^rsstrtt's job (its own description already says "leaf run() payloads flow through the identical AnyOperation.run dispatch path as model calls") — flagging here so it isn't dropped. Left a comment on ^rsstrtt too.

    Verification: `swift build` (clean, 0 warnings) and `swift test` both green — 24 tests in OperationsMacrosTests (14 existing + 10 new: 6 in CommandEmissionTests.swift covering flag/option/repeatable/optional mapping, `@OperationParam(short:)`, the nested-array edge case, and 4 real compile-and-parse tests), 22 in OperationsTests, 1 placeholder in OperationsCLITests. Local `/review` engine: 0 findings. Adversarial double-check: initial REVISE (missing nested-array test coverage, a stale/unverified code comment, an untracked scope decision, a non-verbatim fixture) — all four addressed in follow-up commits to this same working tree.

    Leaving in `doing` for `/review` per the implement skill's contract.
  timestamp: 2026-07-02T20:33:39.551664+00:00
- actor: wballard
  id: 01kwj9g32jd1r9vbeaa2hhd77k
  text: |-
    Addressed the double-check's REVISE findings (4/4):
    1. Added `nestedArrayFieldGetsParamMetaEntryButNoCommandField` assertMacroExpansion test pinning the silent-omission behavior for `[[String]]` fields.
    2. Extracted `private let opFieldName = "op"` (mirroring SchemaFusion.swift's constant) and replaced the three ad hoc `"op"` literals (reserved-name comparison, diagnostic message, generated payload key) with it — flagged by the local `/review` engine, fixed.
    3. Made `AddNoteCommandFixture` verbatim-er to plan.md's `AddNote` example (added `body: String?`), and added a `pinned: Bool` field + 4 new real-compile tests so all four `CommandFieldKind` mappings (required option, optional option, repeatable option, flag) are exercised end-to-end through a real compile, not just `assertMacroExpansion`.
    4. Reworded the stale "OperationTool.call strips it" comment to "will strip" since `OperationTool` doesn't exist yet.

    Final state: clean `rm -rf .build && swift build` — 0 warnings, 0 errors. `swift test` — 49/49 passing (22 OperationsTests, 26 OperationsMacrosTests [14 metadata fixtures + 8 CommandEmissionTests fixtures/expansions + 4 real compile-and-parse tests... actually 8 CommandCompileAndParseTests + 3 CommandEmissionExpansionTests, see file], 1 OperationsCLITests placeholder). Local `/review` engine: 0 findings on final diff. Second adversarial double-check round not re-run per really-done's "bound the loop" guidance (one re-check already applied); all four first-round findings were concretely fixed, not argued around.

    Ready for `/review`. Leaving in `doing`.
  timestamp: 2026-07-02T20:49:32.242157+00:00
depends_on:
- 01KWHQDDNXV5Q1CKH77B5ZKM1R
position_column: doing
position_ordinal: '80'
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