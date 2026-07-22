/// Opt-in context protocol: a `Context` conforming to this exposes the
/// mutable sink holder `OperationTool.connect(_:)` writes to and every
/// operation's `execute(in:)` posts `OperationEvent`s through.
///
/// Conforming is what turns `OperationTool<Context>` into an
/// `EventEmittingTool` (see its conditional conformance in
/// `OperationTool.swift`) — a `Context` that doesn't conform gets no
/// event-posting capability, and `OperationTool`'s `as? any
/// EventEmittingTool` cast simply fails for it. A conforming `Context`
/// ordinarily stores its `operationEventSink` as a `let` — `Context` is
/// copied freely, but `OperationEventSinkHolder` is a reference type, so
/// every copy still shares the same connected sink.
public protocol EventEmittingContext: Sendable {
    /// The holder every event this context's operations post flows through,
    /// and every `connect(_:)` call configures.
    var operationEventSink: OperationEventSinkHolder { get }
}
