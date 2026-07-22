import Foundation
import FoundationModels
import Testing

@testable import Operations

/// Collects every event posted to it, for assertion. Stands in for a real
/// session host's outbox.
private actor FakeEventSinkActor: OperationEventSink {
    private(set) var events: [OperationEvent] = []

    func post(_ event: OperationEvent) async {
        events.append(event)
    }
}

/// A `Context` that opts into event emission by exposing a mutable sink
/// holder — the "opt-in context protocol" `EventEmittingContext` describes.
private struct EmittingFixtureContext: EventEmittingContext {
    let operationEventSink = OperationEventSinkHolder()
}

/// JSON-encodable result produced by `EmitProgressToolFixture.execute(in:)`.
private struct EmittingOutput: Encodable, Sendable, Equatable {
    let done: Bool
}

/// `run job` fixture: posts a `.progress` then a `.completed` event through
/// its context's sink holder while executing, then returns a plain result —
/// exercising posting from inside `execute(in:)` independent of dispatch.
private struct EmitProgressToolFixture: OperationDefinition {
    typealias Context = EmittingFixtureContext
    typealias Output = EmittingOutput

    var correlationID: String

    static let verb = "run"
    static let noun = "job"
    static let operationDescription = "Emits progress and completion events while running"
    static let parameterMetadata: [ParamMeta] = [
        ParamMeta(name: "correlationID", type: .string, required: true, description: "Correlates posted events")
    ]

    static var generationSchema: GenerationSchema {
        GenerationSchema(type: EmitProgressToolFixture.self, description: operationDescription, properties: [])
    }

    init(_ content: GeneratedContent) throws {
        correlationID = try content.value(String.self, forProperty: "correlationID")
    }

    var generatedContent: GeneratedContent {
        GeneratedContent(properties: ["correlationID": correlationID])
    }

    func execute(in context: EmittingFixtureContext) async throws -> EmittingOutput {
        await context.operationEventSink.post(
            OperationEvent(tool: "jobs", op: Self.opString, correlationID: correlationID, kind: .progress, detail: "{\"percent\":50}")
        )
        await context.operationEventSink.post(
            OperationEvent(
                tool: "jobs", op: Self.opString, correlationID: correlationID, kind: .completed, detail: "{\"percent\":100}")
        )
        return EmittingOutput(done: true)
    }
}

/// A plain `Context` with no `EventEmittingContext` conformance, pairing
/// with `PlainToolFixture` to build a non-emitting `OperationTool` for the
/// mixed `[any Tool]` list test.
private struct PlainContext: Sendable {}

/// JSON-encodable result produced by `PlainToolFixture.execute(in:)`.
private struct PlainOutput: Encodable, Sendable, Equatable {
    let echoed: String
}

/// `echo plain` fixture: an ordinary operation over a `Context` that never
/// opts into event emission.
private struct PlainToolFixture: OperationDefinition {
    typealias Context = PlainContext
    typealias Output = PlainOutput

    var message: String

    static let verb = "echo"
    static let noun = "plain"
    static let operationDescription = "Echoes a message back, no event emission"
    static let parameterMetadata: [ParamMeta] = [
        ParamMeta(name: "message", type: .string, required: true, description: "The message to echo")
    ]

    static var generationSchema: GenerationSchema {
        GenerationSchema(type: PlainToolFixture.self, description: operationDescription, properties: [])
    }

    init(_ content: GeneratedContent) throws {
        message = try content.value(String.self, forProperty: "message")
    }

    var generatedContent: GeneratedContent {
        GeneratedContent(properties: ["message": message])
    }

    func execute(in context: PlainContext) async throws -> PlainOutput {
        PlainOutput(echoed: message)
    }
}

@Suite struct EventEmittingToolTests {

    // MARK: - OperationEvent: Codable round trip and wire shape

    @Test func operationEventCodableRoundTripPreservesAllFields() throws {
        let event = OperationEvent(
            tool: "jobs", op: "run job", correlationID: "cid-1", kind: .completed, detail: "{\"percent\":100}")

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(OperationEvent.self, from: data)

        #expect(decoded == event)
    }

    @Test func operationEventEncodesKindAsLowercaseRawStringInJSON() throws {
        let event = OperationEvent(tool: "jobs", op: "run job", correlationID: "cid-1", kind: .progress, detail: "{}")

        let data = try JSONEncoder().encode(event)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"kind\":\"progress\""))
    }

    // MARK: - OperationEventSinkHolder

    @Test func operationEventSinkHolderPostsToConnectedSink() async {
        let holder = OperationEventSinkHolder()
        let sink = FakeEventSinkActor()
        let event = OperationEvent(tool: "t", op: "add x", correlationID: "1", kind: .progress, detail: "{}")

        holder.connect(sink)
        await holder.post(event)

        let events = await sink.events
        #expect(events == [event])
    }

    @Test func operationEventSinkHolderWithNoConnectedSinkPostsIntoTheVoidSafely() async {
        let holder = OperationEventSinkHolder()
        let event = OperationEvent(tool: "t", op: "add x", correlationID: "1", kind: .progress, detail: "{}")

        // Must not crash or throw; nothing is retained anywhere to assert on.
        await holder.post(event)
    }

    @Test func operationEventSinkHolderConnectingASecondSinkReplacesTheFirstRatherThanFanningOut() async {
        // "One sink per tool instance, no fan-out" — connecting again must
        // replace the previous connection, not add a second destination.
        let holder = OperationEventSinkHolder()
        let first = FakeEventSinkActor()
        let second = FakeEventSinkActor()
        let event = OperationEvent(tool: "t", op: "add x", correlationID: "1", kind: .progress, detail: "{}")

        holder.connect(first)
        holder.connect(second)
        await holder.post(event)

        let firstEvents = await first.events
        let secondEvents = await second.events
        #expect(firstEvents.isEmpty)
        #expect(secondEvents == [event])
    }

    @Test func contextCopiesShareTheSameConnectedSinkThroughTheHolderReference() async {
        // `EmittingFixtureContext` is a struct, freely copied — but
        // `operationEventSink` is a reference type, so a copy still posts
        // to whatever sink was connected before the copy was made.
        let context = EmittingFixtureContext()
        let sink = FakeEventSinkActor()
        context.operationEventSink.connect(sink)

        let copy = context
        await copy.operationEventSink.post(
            OperationEvent(tool: "t", op: "x", correlationID: "1", kind: .progress, detail: "{}"))

        let events = await sink.events
        #expect(events.count == 1)
    }

    // MARK: - Cast-and-connect over a mixed [any Tool] list

    @Test func castAndConnectDiscoversTheEventEmittingToolInAMixedAnyToolList() async throws {
        let emittingTool = try OperationTool(
            name: "jobs",
            description: "Job operations",
            context: EmittingFixtureContext(),
            operations: [AnyOperation(EmitProgressToolFixture.self)]
        )
        let plainTool = try OperationTool(
            name: "plain",
            description: "Plain operations",
            context: PlainContext(),
            operations: [AnyOperation(PlainToolFixture.self)]
        )
        let tools: [any Tool] = [plainTool, emittingTool]
        let sink = FakeEventSinkActor()

        var connectedCount = 0
        for tool in tools {
            if let emitter = tool as? any EventEmittingTool {
                emitter.connect(sink)
                connectedCount += 1
            }
        }

        #expect(connectedCount == 1)
        #expect(plainTool as? any EventEmittingTool == nil)

        let arguments = GeneratedContent(properties: ["op": "run job", "correlationID": "cid-1"])
        _ = try await emittingTool.call(arguments: arguments)

        let events = await sink.events
        #expect(events.map(\.kind) == [.progress, .completed])
        #expect(events.allSatisfy { $0.tool == "jobs" && $0.op == "run job" && $0.correlationID == "cid-1" })
    }

    // MARK: - No connected sink: posts into the void safely

    @Test func operationWithNoConnectedSinkDispatchesNormallyWithoutErrorOrRetention() async throws {
        let tool = try OperationTool(
            name: "jobs",
            description: "Job operations",
            context: EmittingFixtureContext(),
            operations: [AnyOperation(EmitProgressToolFixture.self)]
        )
        let arguments = GeneratedContent(properties: ["op": "run job", "correlationID": "cid-2"])

        let json = try await tool.call(arguments: arguments)

        #expect(json.contains("\"done\":true"))
    }
}
