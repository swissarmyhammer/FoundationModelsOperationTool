/// A `Tool` that can post `OperationEvent`s to a connected
/// `OperationEventSink`.
///
/// **Usage contract (pinned): `connect` is host-internal machinery, never an
/// end-user call.** A host receives its tools as an ordinary `[any Tool]`
/// list (e.g. a session's `tools:` parameter), discovers emitters by
/// conformance cast (`tool as? any EventEmittingTool`), and connects them
/// itself during setup — implementing this protocol IS the subscription;
/// nobody "remembers" to connect it separately. `EventEmittingTool` declares
/// no associated types precisely so that cast succeeds against an `any Tool`
/// existential.
public protocol EventEmittingTool {
    /// Connects `sink` to receive every event this tool posts from then on,
    /// replacing any previously connected sink.
    ///
    /// A tool instance connects to one sink at a time — no fan-out. Calling
    /// this again replaces the previous connection rather than adding a
    /// second destination.
    ///
    /// - Parameter sink: The sink to connect.
    func connect(_ sink: any OperationEventSink)
}
