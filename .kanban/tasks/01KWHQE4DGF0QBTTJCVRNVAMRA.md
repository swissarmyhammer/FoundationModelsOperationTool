---
depends_on:
- 01KWHQCVGNFHVT0ZKEDAG802RR
- 01KWHQDMN1ZA38C5HF7ZPPXP1Y
position_column: todo
position_ordinal: '8480'
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
- [ ] Registering the tool on a `LanguageModelSession` compiles (`#available`-guarded)
- [ ] "note add", "ADD NOTE", "create note" all dispatch to a hand-conformed AddNote-shaped fixture (no macro)
- [ ] Unknown-op result is a returned String containing the valid op list, not a thrown error
- [ ] Third consecutive corrective failure returns the terminal message

## Tests
- [ ] `Tests/OperationsTests/OperationToolTests.swift` — dispatch exact/aliased/reordered; unknown-op and missing-required return (not throw) corrective text; key-alias normalization; inference hook; extra-`op`-key tolerance or stripping; retry cap (third consecutive corrective failure in a turn returns the terminal message, not another correction)
- [ ] Run `swift test --filter OperationToolTests`; all pass

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.