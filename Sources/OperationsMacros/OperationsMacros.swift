import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

/// Implements the `@Operation` attached macro declared in the `Operations`
/// module.
///
/// This is a package-scaffolding stub that expands to no extensions. The
/// real member/extension synthesis — `OperationDefinition` conformance,
/// `parameterMetadata`, and the generated `ArgumentParser` `Command` — is
/// implemented in a later task.
struct OperationMacro: ExtensionMacro {
    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        []
    }
}

/// Registers every macro implemented by this plugin with the compiler.
@main
struct OperationsMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        OperationMacro.self
    ]
}
