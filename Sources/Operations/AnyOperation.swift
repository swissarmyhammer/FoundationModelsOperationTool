import FoundationModels
import Foundation

/// A type-erased `OperationDefinition`, keyed to a shared `Context`.
///
/// `OperationDefinition` carries associated types (`Context`, `Output`), so
/// a registry that mixes many operation types together — the whole point of
/// fusing them into one `OperationTool` — has to erase those types away.
/// `AnyOperation` captures an operation's metadata plus a closure, `run`,
/// that decodes a `GeneratedContent` payload into the concrete operation
/// type, executes it, and re-encodes the result as JSON. Dispatch always
/// flows through the typed struct — `run` never touches raw dictionaries.
public struct AnyOperation<Context: Sendable>: Sendable {
    /// The action this operation performs (e.g. `"add"`).
    public let verb: String

    /// The resource this operation acts on (e.g. `"note"`).
    public let noun: String

    /// A human- and model-facing summary of what the operation does.
    public let description: String

    /// One entry per parameter, in declaration order.
    public let parameters: [ParamMeta]

    /// Decodes `content` into the concrete operation type, executes it
    /// against `context`, and returns the JSON-encoded result.
    ///
    /// Throws `OperationError.decodingFailed` if the concrete operation's
    /// `init(_:)` throws, if JSON-encoding its `Output` throws, or if the
    /// encoded JSON isn't valid UTF-8; throws `OperationError.executionFailed`
    /// if `execute(in:)` throws.
    let run: @Sendable (GeneratedContent, Context) async throws -> String

    /// Erases `O` into an `AnyOperation` sharing `O`'s `Context`.
    public init<O: OperationDefinition>(_ type: O.Type) where O.Context == Context {
        verb = O.verb
        noun = O.noun
        description = O.operationDescription
        parameters = O.parameterMetadata
        run = { content, context in
            let operation: O
            do {
                operation = try O(content)
            } catch {
                throw OperationError.decodingFailed
            }

            let output: O.Output
            do {
                output = try await operation.execute(in: context)
            } catch {
                throw OperationError.executionFailed
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data: Data
            do {
                data = try encoder.encode(output)
            } catch {
                throw OperationError.decodingFailed
            }

            guard let json = String(data: data, encoding: .utf8) else {
                throw OperationError.decodingFailed
            }
            return json
        }
    }
}
