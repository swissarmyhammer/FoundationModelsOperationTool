---
comments:
- actor: wballard
  id: 01kyyjs6zjt0ysc1d9ccf7fzj9
  text: 'Downstream adoption cards filed: FoundationModelsShelltool jt19xwc (detached-command terminal events), FoundationModelsMCP zfp4a3j (call terminal events), FoundationModelsACPAgent 2p6913n (plan.md: one total OperationOutcome -> ToolCallStatus mapping in §8.4/§11.5). Each is blocked on this card landing and a released Operations version.'
  timestamp: 2026-08-01T11:54:05.170195+00:00
- actor: claude-code
  id: 01kyysd6p5fvw0c4maanq61wrn
  text: |-
    Implemented per the card:

    1. Added `Sources/Operations/OperationOutcome.swift` — `OperationOutcome` enum: `.succeeded`, `.failed`, `.timedOut`, `.stopped`, `.cancelled`, `.lost`, plus `.other(String)` for forward-compat unknown values. `rawValue: String` gives the snake_case wire form (`timed_out`); `init(rawValue:)` is non-failable and maps unrecognized strings to `.other(_)`. Manual `Codable` conformance (single-value string container) since the associated-value case rules out the synthesized `String`-backed enum Codable. `Sendable`, `Equatable`. Doc comment preserves the `.stopped` vs `.cancelled` vs `.lost` authority distinction and the ACP `_lost` mapping rationale from the card.

    2. `Sources/Operations/OperationEvent.swift` — added `public let outcome: OperationOutcome?`. Swift's synthesized `Codable` already treats `Optional`-typed stored properties with `decodeIfPresent`/omit-if-nil semantics, so no manual `Codable` was needed on `OperationEvent` itself — confirmed via a test that decodes a pre-existing JSON payload with no `outcome` key at all. `init` gained `outcome: OperationOutcome? = nil` as its last parameter so every existing call site (all in `EventEmittingToolTests.swift` — no callers elsewhere in this repo, confirmed via `get callgraph` inbound and a repo-wide grep for `OperationEvent(`) compiles unchanged.

    3. Documented the terminal-event scope contract on `OperationEventKind`'s doc comment (minimum guarantee: a run that posts anything must post exactly one `.completed`; a run that settles in-band may post nothing) and cross-referenced it from `OperationEvent`'s doc comment. Also documented the `outcome` non-nil-iff-`.completed` invariant on the property itself.

    4. `detail` untouched — still opaque, still carries exit codes/isError/progress counts per the card.

    TDD: wrote `Tests/OperationsTests/OperationOutcomeTests.swift` (rawValue mapping, init(rawValue:) round trip, unknown-preserving decode, Codable wire-shape/round-trip) and added outcome-focused tests to `Tests/OperationsTests/EventEmittingToolTests.swift` (default-nil on init, backward-compat decode of a no-outcome-key payload, round trip of a present outcome) before adding the production types — confirmed the whole suite failed to build (`cannot find type 'OperationOutcome'`) before implementing, then all green after.

    One extra fix needed: this repo has a `DocCoverageTests` integration test (`Sources/Operations` public-API doc-comment coverage) that failed on the new `Codable.init(from:)`/`encode(to:)` — added doc comments to satisfy it.

    Full `swift test`: 94+34+44+22 = 194 tests across 4 targets, all green, zero failures, zero warnings.
  timestamp: 2026-08-01T13:49:51.685826+00:00
- actor: claude-code
  id: 01kyysda1dpak95nkaxhpezf0b
  text: |-
    ### implement — changed
    - evidence: `swift build` and `swift test` clean (194 tests, 4 targets, 0 failures, 0 warnings). Files: Sources/Operations/OperationOutcome.swift (new), Sources/Operations/OperationEvent.swift (outcome field + doc contract), Tests/OperationsTests/OperationOutcomeTests.swift (new), Tests/OperationsTests/EventEmittingToolTests.swift (outcome tests added).
    - next: leave in doing for /review.
  timestamp: 2026-08-01T13:49:55.117701+00:00
position_column: doing
position_ordinal: '80'
title: 'Shared terminal-outcome vocabulary: OperationOutcome enum, outcome envelope field, terminal-event contract'
---
## Why

`OperationEvent.detail` is opaque by design ("the emitting tool and the connected host agree on its shape out of band" — `OperationEvent.swift`). That contract worked with one emitter; with two it has become N private dialects a host must parse. Shelltool and FoundationModelsMCP have already diverged on terminal-outcome vocabulary:

- Shelltool terminal statuses: `completed` / `killed` / `timed_out` (snake_case on the wire), plus `exitCode` — `.completed` events posted only for commands that actually detached (`ShellRunner.run(_:wait:events:)`).
- MCP `.completed` detail: `{"outcome": ...}` with `"success"` / `"isError"` / `"timedOut"` / `"cancelled"` / `"lost"` (camelCase `timedOut`) — exactly one `.completed` per call, every call (`MCPToolOperationEvents.swift`, `MCPToolCallOutcome`).

Every host (Router `SessionOutbox` consumers, the coming ACP agent's `tool_call_update` mapping) must know both dialects, and every future event-posting tool (FileTool, CodeContext, Multitool) will invent a third. "How did the run end" is envelope-grade information — the same class of fact as `kind`, which was itself promoted to a typed field for the same reason.

## What

1. **Add `OperationOutcome`** — a `String`-raw-value, snake_case, `Codable`/`Sendable` enum in the `Operations` module:
   - `succeeded` — the work finished and reported success.
   - `failed` — the work finished and reported failure (definitively known — a server said `isError`, a child exited nonzero, a local synthesis that never launched).
   - `timed_out` — the run's own hard timeout ended it.
   - `stopped` — terminated *authoritatively*; the work is certainly dead (Shelltool's `killed`: `killpg(SIGKILL)` on the child's own group).
   - `cancelled` — cancellation was *requested*; the work may continue (MCP's advisory `notifications/cancelled` — honestly "we stopped listening").
   - `lost` — the outcome is unknowable (MCP's transport-drop case; a `ProgressToken` is meaningless across connections).

   Do NOT flatten the authority distinction: `stopped` vs `cancelled` vs `lost` must stay distinct cases. Downstream ACP maps `lost` → `_lost`, never `failed` ("we do not know if this ran").

   Unknown-preserving decoding: an unrecognized raw value decodes to an `other(String)`-style case (mirroring ACP's `_`-prefix extensible-enum position) so a tool can ship a novel outcome without a lockstep release of this leaf. Not every tool can emit every case, and that is fine — what matters is each case means one thing to every consumer.

2. **Add `outcome: OperationOutcome?` to the `OperationEvent` envelope.** Documented invariant: non-nil iff `kind == .completed`. Decode with `decodeIfPresent` (default `nil`) so previously recorded events — Router journals `OperationEventSegment`s into committed transcripts — still decode. `init` gains the parameter with a `nil` default so existing call sites compile unchanged.

3. **Document the terminal-event scope contract** on `OperationEvent`/`OperationEventKind` as a minimum guarantee: *a run that posted any event must post exactly one terminal (`.completed`) event; a run that settles in-band may post nothing.* Both current emitters comply (Shelltool posts only for detached runs; MCP posts one per call, exceeding the minimum — allowed). This puts the lifecycle rule where the type lives instead of in two packages' private headers.

4. **`detail` stays opaque** for everything genuinely tool-specific (`exitCode`, `isError` provenance, progress counts, notification counts). The opacity contract survives; only the one fact every host branches on moves to the envelope.

## Downstream (separate cards, their boards)

- FoundationModelsShelltool: populate `outcome` on its detached-command `.completed` event.
- FoundationModelsMCP: populate `outcome` from `MCPToolCallOutcome`; keep detail payload for provenance.
- FoundationModelsACPAgent (plan-only): §8.4/§11.5 mapping becomes one total function `OperationOutcome → ToolCallStatus`.