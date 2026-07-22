/// The category of a posted `OperationEvent`: whether a long-running
/// operation is still running, or has finished.
public enum OperationEventKind: String, Codable, Sendable, Equatable {
    /// The operation is still running; `OperationEvent.detail` describes its
    /// current progress.
    case progress

    /// The operation has finished; `OperationEvent.detail` describes its
    /// final result.
    case completed
}

/// A standard progress/completion event a long-running operation posts
/// through a connected `OperationEventSink`.
///
/// This is the vocabulary every fused tool and every session host shares:
/// a tool posts these from inside `OperationDefinition.execute(in:)` (via an
/// `EventEmittingContext`'s sink holder) without knowing anything about the
/// host that will observe them, and a host consumes them through
/// `OperationEventSink` without knowing anything about the tool that posted
/// them. Neither side depends on the other — only on this shared type.
public struct OperationEvent: Codable, Sendable, Equatable {
    /// The fused tool's name (`OperationTool.name`) that posted this event.
    public let tool: String

    /// The canonical `"verb noun"` op string of the operation that posted
    /// this event (see `OperationDefinition.opString`).
    public let op: String

    /// A tool-assigned identifier correlating every event from the same
    /// logical operation run (e.g. a shell tool's commandID). Opaque to this
    /// package — it never interprets or generates one itself.
    public let correlationID: String

    /// Whether this event reports in-progress state or completion.
    public let kind: OperationEventKind

    /// A JSON-string payload describing this event, in whatever shape the
    /// emitting tool defines and owns. Opaque to this package: neither
    /// `OperationEvent` nor `OperationEventSink` interpret it — the emitting
    /// tool and the connected host agree on its shape out of band.
    public let detail: String

    /// Creates an event with the given fields.
    ///
    /// - Parameters:
    ///   - tool: The fused tool's name that posted this event.
    ///   - op: The canonical `"verb noun"` op string of the posting
    ///     operation.
    ///   - correlationID: A tool-assigned identifier correlating every event
    ///     from the same logical operation run.
    ///   - kind: Whether this event reports in-progress state or completion.
    ///   - detail: A JSON-string payload describing this event, in whatever
    ///     shape the emitting tool defines and owns.
    public init(tool: String, op: String, correlationID: String, kind: OperationEventKind, detail: String) {
        self.tool = tool
        self.op = op
        self.correlationID = correlationID
        self.kind = kind
        self.detail = detail
    }
}
