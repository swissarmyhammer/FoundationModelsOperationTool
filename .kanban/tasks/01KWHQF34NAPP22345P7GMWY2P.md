---
depends_on:
- 01KWHQQNZ644BZC5G1M4XGV0J0
- 01KWHQE4DGF0QBTTJCVRNVAMRA
- 01KWHQEN01Q45DWC20MRSSTRTT
position_column: todo
position_ordinal: '8680'
title: 'NotesTool example: dual-use end-to-end + live-model validation harness'
---
## What
`Examples/NotesTool/` executable target per plan.md task 7: 4–5 macro-declared ops (add/get/list/delete note, maybe tag note) over an in-memory `NotesContext` store. Two modes:
- default: `notes note add …` CLI via `OperationCLIDriver`
- `--chat`: registers the `OperationTool` on a `LanguageModelSession` (guarded by `SystemLanguageModel` availability; prints a clear skip message off-device)
The `--chat` harness validates the decided flat-union schema: scripted prompt set measuring op-call accuracy, rendered tool-definition size via `tokenCount(for:)` including the `includesSchemaInInstructions` on/off delta, and retry-cap behavior on deliberately invalid prompts. Results printed as a small report (manual-run, not CI).

## Acceptance Criteria
- [ ] Every op works through both surfaces: CLI invocation and direct `AnyOperation.run`
- [ ] `swift run notes --chat` runs the scripted validation on-device and degrades gracefully off-device
- [ ] Token-count report prints schema size with the includesSchemaInInstructions delta

## Tests
- [ ] `Tests/OperationsCLITests/NotesIntegrationTests.swift` (or example test target) — integration tests exercising every op through `AnyOperation` and through the CLI driver, asserting on store state and JSON output; live-model path excluded from CI but exercised by the scripted `swift run notes --chat`
- [ ] Run `swift test`; full suite green

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.