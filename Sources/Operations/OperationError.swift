/// Errors surfaced while resolving, decoding, or dispatching an operation.
///
/// Most of these are not `throw`n across the `FoundationModels.Tool.call`
/// boundary — per plan.md's "Error handling — return, don't throw", the
/// fused `OperationTool` catches them and returns a corrective message as
/// the tool's `String` output so the model can retry within the turn.
/// `AnyOperation.run` throws `OperationError` for the dispatch layer above
/// it to make that translation.
public enum OperationError: Error, Sendable, Equatable {
    /// No operation matches the resolved `op` string; `valid` lists every
    /// `opString` the registry knows about.
    case unknownOperation(valid: [String])

    /// One or more required parameters were absent from the payload.
    case missingRequired([String])

    /// The payload could not be decoded into the target operation's typed
    /// representation (e.g. `OperationDefinition.init(_:)` threw).
    case decodingFailed

    /// The operation's `execute(in:)` threw.
    case executionFailed
}
