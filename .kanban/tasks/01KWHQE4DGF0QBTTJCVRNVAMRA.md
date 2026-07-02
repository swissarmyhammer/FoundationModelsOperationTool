---
comments:
- actor: wballard
  id: 01kwjgdty41vm9dscf3fq35s4b
  text: |-
    Implemented `OperationTool` + `OperationResolver` per plan.md.

    **New files:**
    - `Sources/Operations/OperationKeys.swift` — shared key-normalization utility (`opFieldName`/`opFieldDescription`/`normalized(_:)`), extracted from `SchemaFusion.swift`'s private duplicate so `OperationResolver` can reuse it instead of re-implementing (SchemaFusion.swift updated to reference it; net removal of the old private duplicate).
    - `Sources/Operations/OperationResolver.swift` — `OperationResolver` struct: `defaultVerbAliases` table (create/new→add, show/read/fetch→get, remove/rm/del→delete) merged with per-tool overrides; `extractedOpString(from:)` (explicit `op` field, else `inferOp` hook); `matchOpString(_:against:)` (case/separator/reordering-tolerant, verb-alias aware); `resolveParameters(_:matching:)` (canonical name → declared alias → normalized canonical → normalized alias, in that priority, rebuilding a canonically-keyed `GeneratedContent` that drops `op` and unrecognized keys — this is how "extra key tolerance" is satisfied, by construction rather than relying on undocumented `@Generable` init behavior).
    - `Sources/Operations/OperationTool.swift` — `OperationTool<Context>: Tool` (`Arguments = GeneratedContent`, `Output = String`); `parameters` built once via `SchemaFusion.fuse` at init; `call(arguments:)` pipeline: resolve op → resolve+validate params → dispatch → return JSON, with unknown-op/missing-required/decoding failures *returned* as corrective text (not thrown) per plan.md's "return, don't throw"; `executionFailed`/`encodingFailed` rethrow as fatal. Retry cap implemented via a private `actor RetryState` (needed because `OperationTool` is a value type but `Tool.call` is `@concurrent`) — default cap 2, third consecutive corrective failure returns the terminal message, counter resets on success or on emitting the terminal message.

    **Modified:**
    - `Sources/Operations/OperationError.swift` — added `CustomStringConvertible` (mirrors `SchemaFusionError`'s existing pattern in this package) so corrective-message text lives in one place instead of being hand-built at each call site.

    **Tests:** `Tests/OperationsTests/OperationToolTests.swift`, 18 tests, all hand-conformed fixtures (no macro dependency, per the task). Covers: real `LanguageModelSession(tools:)` registration (not just a type-check — asserts the transcript records the instructions entry); exact/case-insensitive/reordered/verb-aliased/separator-normalized/case-insensitive-aliased op dispatch; unknown-op and missing-op-field corrective messages (list valid ops); missing-required corrective message; declared-alias and camelCase/snake_case-normalized key resolution; explicit canonical key beats an alias; inference hook; extra-`op`-key tolerance; retry cap (2nd vs 3rd consecutive failure, reset on success, reset after terminal message).

    **Verification:** `rm -rf .build && swift build` clean, zero warnings; `swift test` — 67 tests total across the package (40 Operations/OperationsTests incl. the 18 new, 26 macros, 1 CLI placeholder), zero failures.

    **Review:** ran `/review` on the working diff three times, fixing two real findings (missing doc comments on `OperationTool.Arguments`/`Output` typealiases; a coverage gap — added `dispatchesCaseInsensitiveVerbAliasOpString`). One remaining finding (`case let .unknownOperation(valid):` vs `case .unknownOperation(let valid):` in the new `OperationError` extension) was left as-is: it matches `SchemaFusionError`'s identical, adjacent pre-existing pattern in the same file family, and the codebase already has both styles in different targets (macro target uses `case .x(let y)`, core `Operations` error types use `case let .x(y)`). Not a correctness issue, and flipping it would make it inconsistent with the pattern I copied it from.

    Task left in `doing`, ready for `/review`.
  timestamp: 2026-07-02T22:50:38.404902+00:00
depends_on:
- 01KWHQCVGNFHVT0ZKEDAG802RR
- 01KWHQDMN1ZA38C5HF7ZPPXP1Y
position_column: doing
position_ordinal: '80'
title: 'OperationTool: Tool conformance, dispatch, forgiving resolver, retry cap'
---
## What
`Sources/Operations/OperationTool.swift` + `OperationResolver.swift` per plan.md "Fusing into one Tool" / "Forgiving input" / "Error handling":
- `struct OperationTool<Context: Sendable>: Tool` with `Arguments = GeneratedContent`, `Output = String`, `parameters` = fused flat-union schema (built once at init), configurable `includesSchemaInInstructions`
- `call(arguments:)` pipeline: forgiving-resolve op → look up AnyOperation → validate required params from ParamMeta → `run(content, context)`
- **Return, don't throw**: unknown op / missing required / unparseable values RETURN a corrective String output listing valid ops or missing params; `throw` only for fatal conditions
- **Retry cap**: after 2 corrective failures in a session turn, return terminal "invalid operation, stopping" message (counter resettable per turn)
- `OperationResolver`: case-insensitive op match tolerant of "noun verb" reordering and `_`/`-` separators; shared verb-alias table (create/new→add, show/read/fetch→get, remove/rm/del→delete, …) extensible per tool; key aliases from ParamMeta.aliases + camelCase/snake_case normalization never clobbering explicit canonical keys; optional per-tool inference closure `(GeneratedContent) -> String?`
- Strip `op` (and non-parameter keys) before typed construction if the `@Generable` init proves intolerant of extras — verify with a test either way

Fixtures: use hand-conformed (no-macro) operation structs — this task does not depend on the macro task.

## Acceptance Criteria
- [x] Registering the tool on a `LanguageModelSession` compiles (`#available`-guarded)
- [x] "note add", "ADD NOTE", "create note" all dispatch to a hand-conformed AddNote-shaped fixture (no macro)
- [x] Unknown-op result is a returned String containing the valid op list, not a thrown error
- [x] Third consecutive corrective failure returns the terminal message

## Tests
- [x] `Tests/OperationsTests/OperationToolTests.swift` — dispatch exact/aliased/reordered; unknown-op and missing-required return (not throw) corrective text; key-alias normalization; inference hook; extra-`op`-key tolerance or stripping; retry cap (third consecutive corrective failure in a turn returns the terminal message, not another correction)
- [x] Run `swift test --filter OperationToolTests`; all pass

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.