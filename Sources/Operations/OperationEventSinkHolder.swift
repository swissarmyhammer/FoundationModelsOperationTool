import Foundation

/// A reference-type holder for one connected `OperationEventSink`.
///
/// `OperationTool`'s `Context` is a value type, copied to every fused
/// operation's `execute(in:)` — a plain stored sink property on `Context`
/// couldn't be mutated by `OperationTool.connect(_:)` and be observed by
/// those copies. A `Context` that opts into `EventEmittingContext` instead
/// holds a reference to one `OperationEventSinkHolder`, so `connect(_:)`
/// (host setup) and every `execute(in:)`'s `post(_:)` (operation dispatch)
/// share the same underlying storage regardless of how many times `Context`
/// itself is copied.
///
/// Thread-safe: `connect(_:)` and `post(_:)` may run concurrently, since
/// `Tool.call(arguments:)` may dispatch concurrently across invocations.
public final class OperationEventSinkHolder: OperationEventSink, @unchecked Sendable {
    private let lock = NSLock()
    private var sink: (any OperationEventSink)?

    /// Creates an empty holder — no sink connected until `connect(_:)` is
    /// called.
    public init() {}

    /// Connects `sink`, replacing any previously connected sink. One sink at
    /// a time; no fan-out.
    ///
    /// - Parameter sink: The sink to connect.
    public func connect(_ sink: any OperationEventSink) {
        lock.withLock { self.sink = sink }
    }

    /// Posts `event` to the connected sink, if any.
    ///
    /// Safely a no-op — no error, no retained event — when nothing is
    /// connected yet, satisfying `EventEmittingTool`'s "posts into the void"
    /// guarantee for a tool nobody has connected.
    ///
    /// - Parameter event: The event to post.
    public func post(_ event: OperationEvent) async {
        let current = lock.withLock { sink }
        await current?.post(event)
    }
}
