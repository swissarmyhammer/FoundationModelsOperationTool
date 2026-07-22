---
comments:
- actor: claude-code
  id: 01ky5vwk5jzp5wwm3ej6sen6xy
  text: |-
    Implemented via TDD. New files in Sources/Operations: OperationEvent.swift (OperationEvent struct + OperationEventKind enum, Codable/Sendable/Equatable), OperationEventSink.swift (the Sendable `post(_:) async` protocol), EventEmittingTool.swift (the `connect(_:)` protocol, no associated types so it casts from `any Tool`), OperationEventSinkHolder.swift (a `final class ... : OperationEventSink, @unchecked Sendable` using `NSLock.withLock` — not an `actor`, because `EventEmittingTool.connect` is specified synchronous per the task/acceptance text, and an actor-backed holder would force `connect` to fire-and-forget a `Task`, racing the very next dispatch in a test), EventEmittingContext.swift (the opt-in `Context` protocol exposing `var operationEventSink: OperationEventSinkHolder { get }`). Added a conditional-conformance extension in OperationTool.swift: `extension OperationTool: EventEmittingTool where Context: EventEmittingContext`, forwarding `connect(_:)` to `context.operationEventSink.connect(_:)`. Since `OperationEventSinkHolder` is a reference type held by a value-type `Context`, every copy of `Context` (including the one captured inside `OperationTool.init` and the one handed to each `execute(in:)`) shares the same connected sink — verified directly by a test.

    Design note not spelled out in the task: "tool" and "op" on `OperationEvent` are supplied by the operation author when constructing the event inside `execute(in:)` (no auto-stamping) — kept minimal per the task's literal `OperationEvent` field list; operations already know their own `Self.opString`, and the fused tool's `name` is coordinated by the app author who wires both together.

    TDD: wrote Tests/OperationsTests/EventEmittingToolTests.swift first, watched it fail to compile (types didn't exist), then implemented until green, then added two more regression tests during self-review (adversarial double-check via the `double-check` skill — the Task-tool subagent wasn't available in this environment, so I ran the adversarial pass directly per the skill's documented process): connecting a second sink replaces rather than fans out, and a `Context` copy still shares the same connected sink through the holder reference.

    Tests: `swift test` fully green — 82+34+44+22 = 182 tests across OperationsTests/OperationsMacrosTests/OperationsCLITests/NotesToolTests, 0 failures, 0 errors, 0 warnings. The "every public declaration in Sources/Operations has an attached doc comment" doc-coverage test passes against the new files. `swift build` clean.

    Left in `doing` for review per the /implement process.
  timestamp: 2026-07-22T21:32:12.338607+00:00
- actor: claude-code
  id: 01ky5vxtb9pnrnvz4w7pzz62jj
  text: 'Implemented via TDD: OperationEvent, OperationEventSink, EventEmittingTool, OperationEventSinkHolder, EventEmittingContext in Sources/Operations/. OperationTool gains conditional EventEmittingTool conformance when Context: EventEmittingContext. New test file EventEmittingToolTests.swift covers Codable round-trip, no-sink safety, no-fan-out-on-reconnect, context-copy sink sharing, and the mixed-[any Tool]-list cast-and-connect acceptance scenario. swift test: 182 tests, 0 failures, 0 warnings. Task left in doing for review.'
  timestamp: 2026-07-22T21:32:52.457952+00:00
position_column: done
position_ordinal: '9880'
title: Standard progress/completion event vocabulary and EventEmitting protocol
---
## What

Make progress/completion events a standard capability of operation tools, so any session host that knows one protocol can receive events from any fused tool. This is the seam long-running tools (first consumer: FoundationModelsShelltool's detached shell commands) post through and session hosts (first consumer: FoundationModelsRouter's session outbox) connect to — tools and hosts never depend on each other, only on this package.

Design and land:
- `OperationEvent` (`Codable`, `Sendable`): `tool` (fused tool name), `op` (operation string), `correlationID` (tool-assigned, e.g. a shell commandID), `kind` (`.progress` / `.completed`), and a small `Codable` detail payload (propose a JSON-string `detail` the emitting tool owns; refine against this package's conventions).
- `OperationEventSink` (`Sendable` protocol): `func post(_ event: OperationEvent) async`.
- `EventEmittingTool` protocol with `func connect(_ sink: any OperationEventSink)`. **Usage contract (pinned): `connect` is host-internal machinery, never an end-user call.** A host receives tools as an ordinary `[any Tool]` list (e.g. a session's `tools:` parameter), discovers emitters by conformance cast (`tool as? any EventEmittingTool`), and connects them itself during setup — implementing the protocol IS the subscription; nobody "remembers to connect". The protocol must therefore be discoverable from an `any Tool` existential (design the conformance so the cast works on the concrete fused-tool type).
- Design how `OperationTool<Context>` plumbs a connected sink through to operations' `execute(in:)` contexts (e.g. an opt-in context protocol with a mutable sink holder, since contexts are value types shared across ops). A tool instance connects to one sink — no fan-out (document; do not build speculatively). Follow this package's existing resolver/fusion design idioms and its DESIGN_NOTES/doc-coverage conventions.

## Acceptance Criteria
- [x] Given a `[any Tool]` list containing a fused `OperationTool` whose context opted in, a host can discover it via `as? any EventEmittingTool` and connect a sink — verified by a test that does exactly this cast-and-connect over a mixed list
- [x] An operation's `execute(in:)` can post `.progress`/`.completed` events that arrive at the connected sink with tool/op/correlationID intact
- [x] A tool with no connected sink posts into the void safely (no error, no retention of events)
- [x] Public API documented per the doc-coverage gate, including the "hosts connect, users don't" contract

## Tests
- [x] Unit tests: cast-and-connect over a mixed `[any Tool]` list + post round-trip through a fake sink actor; no-sink no-op; event Codable round-trip
- [x] `swift test` fully green

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #long-running