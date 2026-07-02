import FoundationModels

/// Re-exported so that any target which imports `Operations` — including
/// macro-generated `Command` types produced by `@Operation` — has
/// `ArgumentParser` available without declaring its own dependency on
/// swift-argument-parser.
@_exported import ArgumentParser

/// Attaches verb, noun, and description metadata to an operation type.
///
/// `@Operation` marks a `Generable` struct as a fused-tool operation: its
/// stored properties are the operation's parameters. This macro synthesizes
/// `OperationDefinition` conformance — the `verb`/`noun`/`operationDescription`
/// statics and a `parameterMetadata: [ParamMeta]` table derived from the
/// struct's stored properties (type mapping, `Optional` ⇒ not required,
/// `@Guide(description:)` / doc-comment description, `@OperationParam`
/// short/aliases/allowedValues).
///
/// The macro-generated `ArgumentParser` `Command` for the dual-use CLI is
/// synthesized by a later task; this macro covers metadata only.
///
/// - Parameters:
///   - verb: The action the operation performs (e.g. `"add"`).
///   - noun: The resource the operation acts on (e.g. `"note"`).
///   - description: A human- and model-facing summary of what the operation
///     does.
@attached(extension, conformances: OperationDefinition, names: named(verb), named(noun), named(operationDescription), named(parameterMetadata))
public macro Operation(verb: String, noun: String, description: String) =
    #externalMacro(module: "OperationsMacros", type: "OperationMacro")

/// Marks a stored property of an `@Operation` struct with CLI-facing
/// affordances that have no `@Generable`/`@Guide` equivalent.
///
/// `@Operation` reads this attribute's arguments while synthesizing
/// `parameterMetadata`, but `@OperationParam` itself expands to nothing — it
/// is a pure marker, inspected as sibling syntax rather than generating any
/// code of its own.
///
/// - Parameters:
///   - short: A single-character CLI short flag (e.g. `"t"` for `--title`).
///   - aliases: Alternate parameter names the forgiving resolver accepts in
///     place of the property's name.
///   - allowedValues: The closed set of string values this parameter
///     accepts, if constrained. Takes precedence over a recognized literal
///     `@Guide(.anyOf([...]))` on the same property.
@attached(peer)
public macro OperationParam(short: Character? = nil, aliases: [String] = [], allowedValues: [String]? = nil) =
    #externalMacro(module: "OperationsMacros", type: "OperationParamMacro")
