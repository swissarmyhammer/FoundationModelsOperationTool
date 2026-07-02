---
comments:
- actor: wballard
  id: 01kwj8k5w78acs47y6fmvfe005
  text: 'Heads-up from implementing ^4xgv0j0 (@Operation Command emission): the macro-generated `Command.run()` currently only does `print(operationPayload().jsonString)` — it does NOT dispatch through `AnyOperation.run` yet, because there''s no way to obtain a live `Context` instance at the macro-generated-code level (Context is an associated type resolved per concrete operation struct, and nothing in scope of the macro/Command owns a Context instance). `Command.operationPayload() -> GeneratedContent` is the stable, tested extension point (see Tests/OperationsMacrosTests/CommandEmissionTests.swift) — it returns the identical canonical payload shape `AnyOperation.run` expects (minus needing the `op` key stripped, per plan.md''s "GeneratedContent behavior with extra keys" — the `@Generable` init tolerates the extra `op` key fine, verified by `parsedCommandPayloadMatchesTheShapeAnyOperationRunDecodes`). When this task wires up the runtime registry, `run()` (or a driver-level wrapper) should call `operationPayload()` then dispatch through `AnyOperation.run(payload, context)` using whatever context-resolution mechanism this task designs.'
  timestamp: 2026-07-02T20:33:44.839591+00:00
depends_on:
- 01KWHQCVGNFHVT0ZKEDAG802RR
- 01KWHQQNZ644BZC5G1M4XGV0J0
- 01KWHQE4DGF0QBTTJCVRNVAMRA
position_column: todo
position_ordinal: '8580'
title: 'CLI driver: ArgumentParser runtime registry, noun nodes, completions'
---
## What
`Sources/OperationsCLI/OperationCLIDriver.swift` (+ `Registry.swift`, `NounNode.swift`) per plan.md "Dual-use CLI":
- freeze-once registry: `Mutex`-guarded set-then-seal before first parse; populated from one or more `OperationTool`s' operations grouped verb-command-metatypes-by-noun
- generic `NounNode<Rep>` intermediate command whose computed `static configuration` reads the registry (`CommandConfiguration(commandName: Rep.noun, subcommands: ...)`); instantiate one per noun via opened existentials
- root command with computed `static configuration`; multi-tool grammar `<exe> <tool> <noun> <verb>`, tool level collapses with exactly one tool; duplicate tool names rejected at init
- startup assertion pass (duplicate names, malformed tree); correct `tool noun verb` help prefixes via `_superCommandName` or explicit `usage:`
- fallback leaf synthesis from `ParamMeta` for manually-conformed (macro-less) operations
- JSON output printing, exit codes; leaf `run()` payloads flow through the identical `AnyOperation.run` dispatch path as model calls

## Acceptance Criteria
- [ ] `notes note add --title Hi --tags a --tags b` executes AddNote and prints its JSON
- [ ] `--generate-completion-script zsh` output contains every noun, verb, and flag from a runtime-assembled registry — including the macro-less fallback leaf
- [ ] `--help` at root/noun/verb levels shows correct prefixes and descriptions from @Guide text
- [ ] The hand-conformed (macro-less) fixture op from the core-types task appears in `--help` and parses via the synthesized fallback leaf, converging on the same resolver-accepted payload

## Tests
- [ ] `Tests/OperationsCLITests/CLIDriverTests.swift` — argv→payload round-trip equals resolver-accepted payload (convergence contract) incl. `--opt=value`, combined short flags, repeated options, `--`; help snapshots at three levels; completion-script content assertions; multi-tool grammar (two tools ⇒ tool level, one ⇒ collapsed; duplicate names rejected); macro-less fallback leaf round-trip + help/completions presence; unknown noun/verb yields did-you-mean; missing required and bad-int errors
- [ ] Run `swift test --filter CLIDriverTests`; all pass

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.