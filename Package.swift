// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "FoundationModelsOperations",
    // macOS 27 floor: the transitional shim dependency on
    // `FoundationModelsRouter` (see below) requires macOS 27 / FoundationModels
    // v2. `"27.0"` is a string literal rather than the `.v27` enum case, which
    // needs `PackageDescription` 6.4 — this manifest stays on tools-version
    // 6.2, matching the sibling packages (see e.g. `FoundationModelsMCP`'s and
    // `FoundationModelsFileTool`'s `Package.swift`).
    platforms: [
        .macOS("27.0"),
        .iOS(.v26),
    ],
    products: [
        .library(name: "Operations", targets: ["Operations"]),
        .library(name: "OperationsCLI", targets: ["OperationsCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "604.0.0-latest"),
        // Transitional shim dependency (eventplan.md §"Phases" phase 1):
        // Router now owns the shared vocabulary (`OperationEvent`,
        // `OperationOutcome`, `OperationEventSink`, `ForkableTool`) in its
        // `Hosting/` module. `Operations` re-exports those types as
        // typealiases instead of defining them, so the siblings keep
        // compiling against one canonical definition. This pulls MLX
        // transitively into this package's build — accepted, temporary
        // build weight. The shim, and this dependency, die with
        // `FoundationModelsOperationTool` in phase 5.
        .package(url: "git@github.com:swissarmyhammer/FoundationModelsRouter.git", branch: "main"),
    ],
    targets: [
        // Macro implementation target: the `@Operation` / `@OperationParam`
        // attached macros. Depends on swift-syntax to parse and synthesize
        // declarations at compile time.
        .macro(
            name: "OperationsMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Core library: operation protocols, metadata, registry, schema
        // fusion, and `OperationTool`. Links the FoundationModels system
        // framework and re-exports ArgumentParser so that any target
        // applying `@Operation` (whose macro-generated `Command` types
        // conform to `ParsableCommand`) compiles without declaring its own
        // dependency on swift-argument-parser. Also links Router — see the
        // `FoundationModelsRouter` dependency's comment above — so
        // `OperationEvent.swift`, `OperationOutcome.swift`,
        // `OperationEventSink.swift`, and `ForkableTool.swift` can re-export
        // Router's canonical types as typealiases.
        .target(
            name: "Operations",
            dependencies: [
                "OperationsMacros",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "FoundationModelsRouter", package: "FoundationModelsRouter"),
            ]
        ),

        // ArgumentParser registry driver: assembles the noun -> verb command
        // tree from `AnyOperation` metadata at runtime.
        .target(
            name: "OperationsCLI",
            dependencies: [
                "Operations",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        .testTarget(
            name: "OperationsTests",
            dependencies: [
                "Operations",
                "TestSupport",
                // `DocCoverageTests.swift` parses `Sources/Operations` and
                // `Sources/OperationsCLI` with SwiftSyntax to enforce doc
                // coverage on every public declaration.
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "OperationsMacrosTests",
            dependencies: [
                "OperationsMacros",
                // `Operations` (which re-exports ArgumentParser) so
                // CommandEmissionTests.swift can, alongside its
                // assertMacroExpansion fixtures, apply `@Operation` for
                // real and compile-and-parse its generated `Command`.
                "Operations",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "OperationsCLITests",
            dependencies: ["OperationsCLI"]
        ),

        // Example: a "notes" tool exercising the full stack end to end —
        // the `@Operation` macro, schema fusion, `OperationTool` dispatch,
        // and the CLI driver. Split into a library (`NotesToolCore`, so its
        // operations and `OperationTool` factory are `@testable`) and a thin
        // executable (`notes`) per plan.md's task 7, since SwiftPM does not
        // allow a test target to import an executable target's main module.
        .target(
            name: "NotesToolCore",
            dependencies: ["Operations"],
            path: "Examples/NotesTool/Sources/NotesToolCore"
        ),
        .executableTarget(
            name: "notes",
            dependencies: ["NotesToolCore", "Operations", "OperationsCLI"],
            path: "Examples/NotesTool/Sources/notes"
        ),
        .testTarget(
            name: "NotesToolTests",
            dependencies: ["NotesToolCore", "Operations", "OperationsCLI", "TestSupport"],
            path: "Examples/NotesTool/Tests/NotesToolTests"
        ),

        // Test-only support code shared across test targets in different
        // SwiftPM modules (`OperationsTests`, `NotesToolTests`). A plain
        // library target, not a test target, since SwiftPM test targets
        // don't depend on one another — this is the standard idiom for
        // sharing test helpers across otherwise-independent test modules.
        .target(
            name: "TestSupport",
            path: "Tests/TestSupport"
        ),
    ]
)
