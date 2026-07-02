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
                "parameter '\(name)' has an unsupported type; '@Operation' supports String, Int, Double, Bool, Array of those, and Optional wrapping any of those"
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

/// Maps a non-`Optional` field type to the source text of a `ParamType`
/// expression (e.g. `.string`, `.array(of: .string)`), or `nil` if the type
/// isn't one `@Operation` supports.
private func primitiveParamTypeExprText(_ type: TypeSyntax) -> String? {
    if let arrayType = type.as(ArrayTypeSyntax.self) {
        guard let elementText = primitiveParamTypeExprText(arrayType.element) else { return nil }
        return ".array(of: \(elementText))"
    }
    if let identifierType = type.as(IdentifierTypeSyntax.self) {
        switch identifierType.name.text {
        case "String": return ".string"
        case "Int": return ".integer"
        case "Double", "Float": return ".number"
        case "Bool": return ".boolean"
        default: return nil
        }
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

/// Description and `anyOf` allowed values recognized from a property's
/// `@Guide(...)` attribute, per plan.md's extraction contract: only literal
/// `description:` strings and a literal `.anyOf([...])` guide are read;
/// every other `@Guide` constraint form is left to Apple's schema.
private func guideInfo(from attributes: AttributeListSyntax) -> (description: String?, allowedValues: [String]?) {
    var description: String?
    var allowedValues: [String]?

    for element in attributes {
        guard case .attribute(let attribute) = element,
            attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "Guide",
            case .argumentList(let arguments) = attribute.arguments
        else {
            continue
        }

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

/// CLI affordances recognized from a property's `@OperationParam(...)`
/// attribute.
private func operationParamInfo(
    from attributes: AttributeListSyntax
) -> (short: Character?, aliases: [String], allowedValues: [String]?) {
    var short: Character?
    var aliases: [String] = []
    var allowedValues: [String]?

    for element in attributes {
        guard case .attribute(let attribute) = element,
            attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "OperationParam",
            case .argumentList(let arguments) = attribute.arguments
        else {
            continue
        }

        for argument in arguments {
            switch argument.label?.text {
            case "short":
                if let literal = argument.expression.plainStringLiteralValue, let first = literal.first {
                    short = first
                }
            case "aliases":
                if let arrayExpr = argument.expression.as(ArrayExprSyntax.self) {
                    aliases = arrayExpr.elements.compactMap { $0.expression.plainStringLiteralValue }
                }
            case "allowedValues":
                if let arrayExpr = argument.expression.as(ArrayExprSyntax.self) {
                    allowedValues = arrayExpr.elements.compactMap { $0.expression.plainStringLiteralValue }
                }
            default:
                break
            }
        }
    }

    return (short, aliases, allowedValues)
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

        let verbExpr = arguments.first(labeled: "verb")?.expression
        let nounExpr = arguments.first(labeled: "noun")?.expression
        let descriptionExpr = arguments.first(labeled: "description")?.expression

        if verbExpr?.plainStringLiteralValue?.isEmpty ?? (verbExpr == nil) {
            context.diagnose(
                OperationMacroDiagnostic.verbMustNotBeEmpty.diagnose(at: verbExpr.map(Syntax.init) ?? Syntax(node))
            )
        }
        if nounExpr?.plainStringLiteralValue?.isEmpty ?? (nounExpr == nil) {
            context.diagnose(
                OperationMacroDiagnostic.nounMustNotBeEmpty.diagnose(at: nounExpr.map(Syntax.init) ?? Syntax(node))
            )
        }

        let verbText = verbExpr?.trimmedDescription ?? "\"\""
        let nounText = nounExpr?.trimmedDescription ?? "\"\""
        let descriptionText = descriptionExpr?.trimmedDescription ?? "\"\""

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
                    context.diagnose(
                        OperationMacroDiagnostic.unsupportedParameterType(propertyName).diagnose(at: binding)
                    )
                    continue
                }

                if normalizedForReservedCheck(propertyName) == "op" {
                    context.diagnose(
                        OperationMacroDiagnostic.reservedParameterName(propertyName).diagnose(at: identifierPattern)
                    )
                    continue
                }

                guard let (typeExprText, required) = paramTypeInfo(for: typeAnnotation) else {
                    context.diagnose(
                        OperationMacroDiagnostic.unsupportedParameterType(propertyName).diagnose(at: typeAnnotation)
                    )
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
                    let aliasesText = operationParam.aliases.map(swiftStringLiteral).joined(separator: ", ")
                    args.append("aliases: [\(aliasesText)]")
                }
                if let allowedValues {
                    let allowedValuesText = allowedValues.map(swiftStringLiteral).joined(separator: ", ")
                    args.append("allowedValues: [\(allowedValuesText)]")
                }

                paramMetaEntries.append("ParamMeta(\(args.joined(separator: ", ")))")
            }
        }

        let parameterMetadataText: String
        if paramMetaEntries.isEmpty {
            parameterMetadataText = "[]"
        } else {
            let entries = paramMetaEntries.map { "    \($0)," }.joined(separator: "\n")
            parameterMetadataText = "[\n\(entries)\n]"
        }

        let access = structDecl.modifiers.first(where: \.isNeededAccessLevelModifier)
        let accessText = access.map { "\($0.name.text) " } ?? ""

        let membersText = """
            \(accessText)static let verb: String = \(verbText)
            \(accessText)static let noun: String = \(nounText)
            \(accessText)static let operationDescription: String = \(descriptionText)
            \(accessText)static let parameterMetadata: [ParamMeta] = \(parameterMetadataText)
            """

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

// MARK: - `@OperationParam`

/// Implements the `@OperationParam` attached macro declared in the
/// `Operations` module.
///
/// `@OperationParam` is a pure marker: `@Operation` reads its arguments while
/// synthesizing `parameterMetadata`, but the attribute itself expands to no
/// code of its own.
public struct OperationParamMacro: PeerMacro {
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
