import Foundation
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Diagnostics

/// Diagnostic messages emitted while expanding `@Operation`.
enum OperationMacroDiagnostic: DiagnosticMessage {
    /// `@Operation` was attached to a declaration that isn't a struct.
    case requiresStruct

    /// The `verb` argument was absent or an empty string literal.
    case verbMustNotBeEmpty

    /// The `noun` argument was absent or an empty string literal.
    case nounMustNotBeEmpty

    /// A stored property's name normalizes to `"op"`, colliding with the
    /// fused-tool discriminator field.
    case reservedParameterName(String)

    /// A stored property's type isn't one `@Operation` can map to a
    /// `ParamType`.
    case unsupportedParameterType(String)

    var message: String {
        switch self {
        case .requiresStruct:
            return "'@Operation' can only be applied to a struct"
        case .verbMustNotBeEmpty:
            return "'@Operation' requires a non-empty 'verb' string literal argument"
        case .nounMustNotBeEmpty:
            return "'@Operation' requires a non-empty 'noun' string literal argument"
        case .reservedParameterName(let name):
            return
                "parameter '\(name)' is reserved: it normalizes to 'op', which collides with the fused-tool discriminator field"
        case .unsupportedParameterType(let name):
            return
                "parameter '\(name)' has an unsupported type; '@Operation' supports String, Int, Double, Float, Bool, Array of those, and Optional wrapping any of those"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "OperationsMacros", id: "Operation.\(self)")
    }

    var severity: DiagnosticSeverity { .error }
}

extension OperationMacroDiagnostic {
    func diagnose(at node: some SyntaxProtocol) -> Diagnostic {
        Diagnostic(node: Syntax(node), message: self)
    }
}

// MARK: - Syntax helpers

extension LabeledExprListSyntax {
    /// Retrieves the first element with the given argument label.
    fileprivate func first(labeled name: String) -> Element? {
        first { $0.label?.text == name }
    }
}

extension ExprSyntax {
    /// The literal string value of this expression, if it is a plain string
    /// literal with no interpolation.
    fileprivate var plainStringLiteralValue: String? {
        guard let literal = self.as(StringLiteralExprSyntax.self),
            literal.segments.count == 1,
            case .stringSegment(let segment)? = literal.segments.first
        else {
            return nil
        }
        return segment.content.text
    }
}

extension DeclModifierSyntax {
    fileprivate var isNeededAccessLevelModifier: Bool {
        switch name.tokenKind {
        case .keyword(.public): return true
        default: return false
        }
    }
}

/// Escapes `value` as the contents of a Swift double-quoted string literal.
private func swiftStringLiteral(_ value: String) -> String {
    var escaped = ""
    for scalar in value.unicodeScalars {
        switch scalar {
        case "\\": escaped += "\\\\"
        case "\"": escaped += "\\\""
        case "\n": escaped += "\\n"
        case "\t": escaped += "\\t"
        default: escaped.unicodeScalars.append(scalar)
        }
    }
    return "\"\(escaped)\""
}

/// Source text of an empty Swift string literal, used as the default `verb`,
/// `noun`, and `description` text when the corresponding `@Operation(...)`
/// argument is absent.
private let emptyStringLiteralText = "\"\""

/// Normalizes a parameter name for the reserved-`"op"`-name check: lowercased
/// with `_`/`-` separators removed, so `"Op"`, `"_op"`, and `"o-p"` are all
/// caught alongside a literal `"op"`.
private func normalizedForReservedCheck(_ name: String) -> String {
    name.lowercased().filter { $0 != "_" && $0 != "-" }
}

/// Extracts a joined description from a stored property's `///` doc-comment
/// trivia, or `nil` if it carries none.
private func docCommentDescription(from trivia: Trivia) -> String? {
    let lines = trivia.compactMap { piece -> String? in
        guard case .docLineComment(let text) = piece else { return nil }
        var line = Substring(text)
        if line.hasPrefix("///") {
            line = line.dropFirst(3)
        }
        return String(line).trimmingCharacters(in: .whitespaces)
    }
    let joined = lines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    return joined.isEmpty ? nil : joined
}

// MARK: - Type mapping

/// Maps a supported primitive Swift type name to the source text of its
/// corresponding `ParamType` case. The single source of truth for which
/// primitive types `@Operation` supports, so adding or changing a mapping is
/// a one-line edit instead of a switch arm kept in sync by hand.
private let primitiveTypeMapping: [String: String] = [
    "String": ".string",
    "Int": ".integer",
    "Double": ".number",
    "Float": ".number",
    "Bool": ".boolean",
]

/// Maps a non-`Optional` field type to the source text of a `ParamType`
/// expression (e.g. `.string`, `.array(of: .string)`), or `nil` if the type
/// isn't one `@Operation` supports.
private func primitiveParamTypeExprText(_ type: TypeSyntax) -> String? {
    if let arrayType = type.as(ArrayTypeSyntax.self) {
        guard let elementText = primitiveParamTypeExprText(arrayType.element) else { return nil }
        return ".array(of: \(elementText))"
    }
    if let identifierType = type.as(IdentifierTypeSyntax.self) {
        return primitiveTypeMapping[identifierType.name.text]
    }
    return nil
}

/// Maps a field type to `(ParamType source text, required)`, unwrapping a
/// single level of `Optional` (`T?`) to derive `required`. Returns `nil` for
/// unsupported types.
private func paramTypeInfo(for type: TypeSyntax) -> (typeExprText: String, required: Bool)? {
    if let optionalType = type.as(OptionalTypeSyntax.self) {
        guard let text = primitiveParamTypeExprText(optionalType.wrappedType) else { return nil }
        return (text, false)
    }
    guard let text = primitiveParamTypeExprText(type) else { return nil }
    return (text, true)
}

// MARK: - `@Guide` / `@OperationParam` introspection

/// Finds every attribute named `name` in `attributes` and yields its
/// argument list, skipping attributes that carry no parenthesized arguments.
/// Shared by `guideInfo(from:)` and `operationParamInfo(from:)`, which differ
/// only in the attribute name they look for.
private func argumentLists(
    forAttributeNamed name: String,
    in attributes: AttributeListSyntax
) -> [LabeledExprListSyntax] {
    attributes.compactMap { element in
        guard case .attribute(let attribute) = element,
            attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == name,
            case .argumentList(let arguments) = attribute.arguments
        else {
            return nil
        }
        return arguments
    }
}

/// Extracts the literal string values from an array-literal expression, or
/// `nil` if `expr` isn't an array-literal expression. Non-string-literal
/// elements are silently dropped via `compactMap`.
private func extractStringArrayLiterals(from expr: ExprSyntax) -> [String]? {
    guard let arrayExpr = expr.as(ArrayExprSyntax.self) else { return nil }
    return arrayExpr.elements.compactMap { $0.expression.plainStringLiteralValue }
}

/// Description and `anyOf` allowed values recognized from a property's
/// `@Guide(...)` attribute, per plan.md's extraction contract: only literal
/// `description:` strings and a literal `.anyOf([...])` guide are read;
/// every other `@Guide` constraint form is left to Apple's schema.
private func guideInfo(from attributes: AttributeListSyntax) -> (description: String?, allowedValues: [String]?) {
    var description: String?
    var allowedValues: [String]?

    for arguments in argumentLists(forAttributeNamed: "Guide", in: attributes) {
        for argument in arguments {
            if argument.label?.text == "description", let literal = argument.expression.plainStringLiteralValue {
                description = literal
            } else if argument.label == nil, let values = anyOfAllowedValues(from: argument.expression) {
                allowedValues = values
            }
        }
    }

    return (description, allowedValues)
}

/// Recognizes a `.anyOf(["a", "b"])` `GenerationGuide` expression and
/// extracts its literal string values, or `nil` if the expression isn't that
/// recognized shape.
private func anyOfAllowedValues(from expr: ExprSyntax) -> [String]? {
    guard let call = expr.as(FunctionCallExprSyntax.self),
        let memberAccess = call.calledExpression.as(MemberAccessExprSyntax.self),
        memberAccess.base == nil,
        memberAccess.declName.baseName.text == "anyOf",
        call.arguments.count == 1,
        let arrayExpr = call.arguments.first?.expression.as(ArrayExprSyntax.self)
    else {
        return nil
    }

    var values: [String] = []
    for element in arrayExpr.elements {
        guard let literal = element.expression.plainStringLiteralValue else { return nil }
        values.append(literal)
    }
    return values
}

/// Labels of `@OperationParam(...)` arguments whose value is a string-array
/// literal, keyed by label text. Driving `operationParamInfo(from:)`'s loop
/// from this table — rather than one hand-written `case` branch per label —
/// keeps `aliases` and `allowedValues` a single code path instead of two
/// copies that differ only by name.
private let operationParamArrayArgumentLabels = ["aliases", "allowedValues"]

/// CLI affordances recognized from a property's `@OperationParam(...)`
/// attribute.
private func operationParamInfo(
    from attributes: AttributeListSyntax
) -> (short: Character?, aliases: [String], allowedValues: [String]?) {
    var short: Character?
    var arrayArguments: [String: [String]] = [:]

    for arguments in argumentLists(forAttributeNamed: "OperationParam", in: attributes) {
        for argument in arguments {
            guard let label = argument.label?.text else { continue }
            if label == "short" {
                if let literal = argument.expression.plainStringLiteralValue, let first = literal.first {
                    short = first
                }
            } else if operationParamArrayArgumentLabels.contains(label),
                let values = extractStringArrayLiterals(from: argument.expression)
            {
                arrayArguments[label] = values
            }
        }
    }

    return (short, arrayArguments["aliases"] ?? [], arrayArguments["allowedValues"])
}

// MARK: - `@Operation`

/// Implements the `@Operation` attached macro declared in the `Operations`
/// module.
///
/// Synthesizes `OperationDefinition` conformance on the annotated struct:
/// `verb`/`noun`/`operationDescription` statics and a `parameterMetadata`
/// table derived from its stored properties. The macro-generated
/// `ArgumentParser` `Command` for the dual-use CLI is a separate, later
/// task — this macro covers metadata only.
public struct OperationMacro: ExtensionMacro {
    /// Expands `@Operation(verb:noun:description:)` into an
    /// `OperationDefinition` conformance extension on the annotated struct.
    ///
    /// - Parameters:
    ///   - node: The `@Operation(...)` attribute syntax; its `verb`, `noun`,
    ///     and `description` arguments seed the synthesized statics.
    ///   - declaration: The declaration the attribute is attached to. Must
    ///     be a `StructDeclSyntax`; otherwise `.requiresStruct` is diagnosed
    ///     and expansion produces no extension.
    ///   - type: The type being extended, used as the generated extension's
    ///     subject.
    ///   - protocols: The protocols this expansion was asked to conform to.
    ///     Unused: `OperationDefinition` conformance is always synthesized
    ///     regardless of this list.
    ///   - context: The macro expansion context used to emit diagnostics
    ///     (unsupported types, empty `verb`/`noun`, reserved parameter
    ///     names).
    /// - Returns: A single-element array containing the synthesized
    ///   `OperationDefinition` conformance extension, or an empty array if
    ///   `declaration` isn't a struct or `node` carries no argument list.
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(OperationMacroDiagnostic.requiresStruct.diagnose(at: declaration))
            return []
        }

        guard case .argumentList(let arguments) = node.arguments else {
            return []
        }

        let (verbText, nounText, descriptionText) = verbNounDescriptionText(from: arguments, node: node, in: context)

        let paramMetaEntries = synthesizeParameterMetadata(from: structDecl, in: context)
        let parameterMetadataText = formatParameterMetadataText(paramMetaEntries)

        let access = structDecl.modifiers.first(where: \.isNeededAccessLevelModifier)
        let accessText = access.map { "\($0.name.text) " } ?? ""

        let membersText = generateExtensionMembersText(
            accessText: accessText,
            verbText: verbText,
            nounText: nounText,
            descriptionText: descriptionText,
            parameterMetadataText: parameterMetadataText
        )

        let extensionDecl = try ExtensionDeclSyntax(
            """
            extension \(type.trimmed): OperationDefinition {
            \(raw: membersText)
            }
            """
        )

        return [extensionDecl]
    }
}

/// Diagnoses `expr` (via `context`) against `diagnostic`'s non-empty-string
/// requirement when it is absent or an empty string literal. Shared by the
/// `verb` and `noun` checks in `verbNounDescriptionText(from:node:in:)`,
/// which otherwise differ only in the expression and diagnostic case.
///
/// - Parameters:
///   - expr: The argument expression to validate, or `nil` if the argument
///     was omitted entirely.
///   - diagnostic: The diagnostic to emit when validation fails.
///   - node: The attribute syntax, used as the diagnostic location when
///     `expr` is `nil` (so there's no argument expression to point at).
///   - context: The macro expansion context used to emit the diagnostic.
private func validateNonEmptyStringArgument(
    expr: ExprSyntax?,
    diagnostic: OperationMacroDiagnostic,
    node: AttributeSyntax,
    in context: some MacroExpansionContext
) {
    if expr?.plainStringLiteralValue?.isEmpty ?? (expr == nil) {
        context.diagnose(diagnostic.diagnose(at: expr.map(Syntax.init) ?? Syntax(node)))
    }
}

/// Derives the source text of `verb`, `noun`, and `description` from an
/// `@Operation(...)` attribute's argument list, diagnosing (via `context`)
/// when `verb` or `noun` is missing entirely or is an empty string literal.
///
/// - Parameters:
///   - arguments: The `@Operation(...)` attribute's argument list.
///   - node: The attribute syntax, used as the diagnostic location when
///     `verb`/`noun` is missing entirely (so there's no argument expression
///     to point the diagnostic at).
///   - context: The macro expansion context used to emit diagnostics.
/// - Returns: The source text of the `verb`, `noun`, and `description`
///   argument expressions, each defaulting to `emptyStringLiteralText` when
///   absent.
private func verbNounDescriptionText(
    from arguments: LabeledExprListSyntax,
    node: AttributeSyntax,
    in context: some MacroExpansionContext
) -> (verbText: String, nounText: String, descriptionText: String) {
    let verbExpr = arguments.first(labeled: "verb")?.expression
    let nounExpr = arguments.first(labeled: "noun")?.expression
    let descriptionExpr = arguments.first(labeled: "description")?.expression

    validateNonEmptyStringArgument(expr: verbExpr, diagnostic: .verbMustNotBeEmpty, node: node, in: context)
    validateNonEmptyStringArgument(expr: nounExpr, diagnostic: .nounMustNotBeEmpty, node: node, in: context)

    let verbText = verbExpr?.trimmedDescription ?? emptyStringLiteralText
    let nounText = nounExpr?.trimmedDescription ?? emptyStringLiteralText
    let descriptionText = descriptionExpr?.trimmedDescription ?? emptyStringLiteralText

    return (verbText, nounText, descriptionText)
}

/// Diagnoses `propertyName` (via `context`) as having an unsupported
/// parameter type at `location`. Shared by both unsupported-type call sites
/// in `synthesizeParameterMetadata(from:in:)` — a missing type annotation
/// and a type `paramTypeInfo(for:)` can't map — which otherwise differ only
/// in the diagnostic's location.
private func diagnoseUnsupportedParameterType(
    _ propertyName: String,
    at location: some SyntaxProtocol,
    in context: some MacroExpansionContext
) {
    context.diagnose(OperationMacroDiagnostic.unsupportedParameterType(propertyName).diagnose(at: location))
}

/// Formats `"\(key): [...]"` as the source text of a `ParamMeta(...)`
/// array-valued argument. Shared by the `aliases` and `allowedValues`
/// entries in `synthesizeParameterMetadata(from:in:)`, which otherwise
/// differ only in the key, source collection, and when the argument is
/// omitted entirely.
private func arrayArgumentText(key: String, values: [String]) -> String {
    let valuesText = values.map(swiftStringLiteral).joined(separator: ", ")
    return "\(key): [\(valuesText)]"
}

/// Synthesizes one `ParamMeta(...)` source-text entry per eligible stored
/// property of `structDecl`, in declaration order.
///
/// Computed properties (an accessor block present), `static` properties, and
/// properties without a type annotation are skipped. Diagnoses (via
/// `context`) and skips properties with the reserved name `"op"` or with a
/// type `@Operation` can't map to a `ParamType`.
///
/// - Parameters:
///   - structDecl: The struct declaration whose stored properties become
///     parameters.
///   - context: The macro expansion context used to emit diagnostics for
///     invalid properties.
/// - Returns: The source text of each synthesized `ParamMeta(...)` call
///   expression, one per eligible property.
private func synthesizeParameterMetadata(
    from structDecl: StructDeclSyntax,
    in context: some MacroExpansionContext
) -> [String] {
    var paramMetaEntries: [String] = []

    for member in structDecl.memberBlock.members {
        guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
        guard !variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) else { continue }

        for binding in variable.bindings {
            // Computed properties (accessor block present) aren't parameters.
            guard binding.accessorBlock == nil else { continue }
            guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }

            let propertyName = identifierPattern.identifier.text

            guard let typeAnnotation = binding.typeAnnotation?.type else {
                diagnoseUnsupportedParameterType(propertyName, at: binding, in: context)
                continue
            }

            if normalizedForReservedCheck(propertyName) == "op" {
                context.diagnose(
                    OperationMacroDiagnostic.reservedParameterName(propertyName).diagnose(at: identifierPattern)
                )
                continue
            }

            guard let (typeExprText, required) = paramTypeInfo(for: typeAnnotation) else {
                diagnoseUnsupportedParameterType(propertyName, at: typeAnnotation, in: context)
                continue
            }

            let guide = guideInfo(from: variable.attributes)
            let operationParam = operationParamInfo(from: variable.attributes)

            let description = guide.description ?? docCommentDescription(from: variable.leadingTrivia) ?? ""
            let allowedValues = operationParam.allowedValues ?? guide.allowedValues

            var args = [
                "name: \(swiftStringLiteral(propertyName))",
                "type: \(typeExprText)",
                "required: \(required)",
                "description: \(swiftStringLiteral(description))",
            ]
            if let short = operationParam.short {
                args.append("short: \(swiftStringLiteral(String(short)))")
            }
            if !operationParam.aliases.isEmpty {
                args.append(arrayArgumentText(key: "aliases", values: operationParam.aliases))
            }
            // Unlike `aliases`, `allowedValues` distinguishes "unset" (`nil`, no
            // constraint) from "set to an empty closed set" (`[]`), so it's
            // appended whenever non-nil rather than gated on non-empty.
            if let allowedValues {
                args.append(arrayArgumentText(key: "allowedValues", values: allowedValues))
            }

            paramMetaEntries.append("ParamMeta(\(args.joined(separator: ", ")))")
        }
    }

    return paramMetaEntries
}

/// Formats synthesized `ParamMeta(...)` entries as the source text of a
/// `[ParamMeta]` array literal, one entry per line.
///
/// - Parameter entries: The `ParamMeta(...)` call-expression source text
///   produced by `synthesizeParameterMetadata(from:in:)`.
/// - Returns: `"[]"` when `entries` is empty, otherwise a multi-line array
///   literal with each entry indented and comma-terminated.
private func formatParameterMetadataText(_ entries: [String]) -> String {
    guard !entries.isEmpty else { return "[]" }
    let joined = entries.map { "    \($0)," }.joined(separator: "\n")
    return "[\n\(joined)\n]"
}

/// Builds the source text of the `OperationDefinition` conformance's static
/// members: `verb`, `noun`, `operationDescription`, and `parameterMetadata`.
///
/// - Parameters:
///   - accessText: The access-level modifier text to prefix each member
///     with (e.g. `"public "`), or `""` for no explicit modifier.
///   - verbText: The source text of the `verb` static's initializer.
///   - nounText: The source text of the `noun` static's initializer.
///   - descriptionText: The source text of the `operationDescription`
///     static's initializer.
///   - parameterMetadataText: The source text of the `parameterMetadata`
///     static's `[ParamMeta]` initializer, as produced by
///     `formatParameterMetadataText(_:)`.
/// - Returns: The declaration source text for all four static members,
///   ready to splice into the generated extension's body.
private func generateExtensionMembersText(
    accessText: String,
    verbText: String,
    nounText: String,
    descriptionText: String,
    parameterMetadataText: String
) -> String {
    """
    \(accessText)static let verb: String = \(verbText)
    \(accessText)static let noun: String = \(nounText)
    \(accessText)static let operationDescription: String = \(descriptionText)
    \(accessText)static let parameterMetadata: [ParamMeta] = \(parameterMetadataText)
    """
}

// MARK: - `@OperationParam`

/// Implements the `@OperationParam` attached macro declared in the
/// `Operations` module.
///
/// `@OperationParam` is a pure marker: `@Operation` reads its arguments while
/// synthesizing `parameterMetadata`, but the attribute itself expands to no
/// code of its own.
public struct OperationParamMacro: PeerMacro {
    /// Expands `@OperationParam(short:aliases:allowedValues:)`.
    ///
    /// This is a no-op expansion: `@OperationParam` exists only to be read
    /// back out by `OperationMacro`'s `operationParamInfo(from:)` while it
    /// synthesizes `parameterMetadata`, so this peer macro never emits any
    /// declarations of its own.
    ///
    /// - Parameters:
    ///   - node: The `@OperationParam(...)` attribute syntax (unused here;
    ///     its arguments are read directly by `operationParamInfo(from:)`).
    ///   - declaration: The declaration the attribute is attached to
    ///     (unused).
    ///   - context: The macro expansion context (unused; this expansion
    ///     never diagnoses).
    /// - Returns: An empty array; this macro never produces peer
    ///   declarations.
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

/// Registers every macro implemented by this plugin with the compiler.
@main
struct OperationsMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        OperationMacro.self,
        OperationParamMacro.self,
    ]
}
