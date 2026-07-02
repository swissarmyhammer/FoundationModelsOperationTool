import FoundationModels

/// Re-exported so that any target which imports `Operations` — including
/// macro-generated `Command` types produced by `@Operation` — has
/// `ArgumentParser` available without declaring its own dependency on
/// swift-argument-parser.
@_exported import ArgumentParser

/// Attaches verb, noun, and description metadata to an operation type.
///
/// `@Operation` marks a `Generable` struct as a fused-tool operation: its
/// stored properties are the operation's parameters, and this macro is
/// responsible for synthesizing the `OperationDefinition` conformance
/// (verb/noun/description statics, `parameterMetadata`) plus a
/// macro-generated `ArgumentParser` `Command` for the dual-use CLI.
///
/// This declaration is a package-scaffolding stub — the synthesis itself is
/// implemented in a later task.
///
/// - Parameters:
///   - verb: The action the operation performs (e.g. `"add"`).
///   - noun: The resource the operation acts on (e.g. `"note"`).
///   - description: A human- and model-facing summary of what the operation
///     does.
@attached(extension)
public macro Operation(verb: String, noun: String, description: String) =
    #externalMacro(module: "OperationsMacros", type: "OperationMacro")
