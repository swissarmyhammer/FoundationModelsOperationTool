---
comments:
- actor: wballard
  id: 01kwhsm3x1jra22sb7f53w91fw
  text: |-
    Implemented package scaffolding per plan.md Task 1.

    Created:
    - Package.swift — swift-tools 6.2, platforms .macOS(.v26)/.iOS(.v26), deps: swift-argument-parser `from: "1.8.0"` and swift-syntax `from: "604.0.0-latest"` (matches installed Swift 6.4 / Xcode 27 beta toolchain — this exact version string is what `swift package init --type macro` generates on this machine, verified empirically).
    - Sources/Operations/Operations.swift — `@_exported import ArgumentParser`, `import FoundationModels`, and the `@Operation` attached-extension macro declaration stub (`#externalMacro(module: "OperationsMacros", type: "OperationMacro")`).
    - Sources/OperationsMacros/OperationsMacros.swift — `.macro` target; `OperationMacro: ExtensionMacro` stub returning `[]`; `@main OperationsMacrosPlugin: CompilerPlugin` registration.
    - Sources/OperationsCLI/OperationsCLI.swift — placeholder `OperationsCLI` enum, depends on Operations + ArgumentParser directly (per plan bullet).
    - Tests/{OperationsTests,OperationsMacrosTests,OperationsCLITests}/PlaceholderTests.swift — swift-testing `@Test`s. OperationsTests has two tests: a trivial placeholder, plus one that references `ParsableCommand.Type` with NO direct ArgumentParser dependency declared for that target — proves acceptance criterion 4 (re-export through Operations) rather than just asserting it.

    Notable environment finding: on this toolchain (Xcode 27 beta / Swift 6.4), the `.macro(...)` target factory lives in a separate `CompilerPluginSupport` module, not the base `PackageDescription` module — `import CompilerPluginSupport` is required in Package.swift alongside `import PackageDescription`, confirmed by generating a scratch `swift package init --type macro` template and diffing its manifest. Without that import, `.macro` errors as "no member 'macro'" regardless of swift-tools-version (tried 5.9 through 6.4).

    Verification: `rm -rf .build && swift build` — clean build, 0 warnings, 0 errors. `swift test` — 4 tests pass (2 in OperationsTests, 1 each in OperationsMacrosTests/OperationsCLITests), 0 failures. Adversarial double-check agent independently re-ran build+test fresh and returned PASS with no findings.

    Leaving task in doing for review.
  timestamp: 2026-07-02T16:12:06.945760+00:00
position_column: doing
position_ordinal: '80'
title: 'Package scaffolding: Package.swift, targets, test skeletons'
---
## What
Create the Swift package skeleton per plan.md "Package layout". `Package.swift` at repo root: swift-tools 6.2, platforms `.macOS(26)` / `.iOS(26)`, dependencies `swift-syntax` (macros target) and `swift-argument-parser` 1.8+. Targets:
- `Sources/Operations/` (core library; links FoundationModels system framework; **depends on ArgumentParser** — macro-generated `Command` types compile inside any target that applies `@Operation`, so Operations re-exports it)
- `Sources/OperationsMacros/` (macro implementation target, swift-syntax)
- `Sources/OperationsCLI/` (depends on Operations + ArgumentParser)
- `Tests/OperationsTests/`, `Tests/OperationsMacrosTests/`, `Tests/OperationsCLITests/` (all three also get ArgumentParser via Operations)
Each source target gets one placeholder file; each test target one placeholder swift-testing test. Wire the macro target with `.macro(...)` and expose it from Operations via an attached-macro declaration stub (empty for now).
Note for CI: building requires the macOS 26 SDK and running `swift test` requires macOS 26 *runners* (schema/GeneratedContent tests construct framework types at runtime); CI scope is build + non-model tests.

## Acceptance Criteria
- [x] `swift build && swift test` run headlessly from a clean checkout (SwiftPM only — no Xcode project, no GUI)
- [x] One placeholder test passes in each of the three test targets
- [x] `Package.swift` pins swift-argument-parser `from: "1.8.0"` and swift-syntax matching the toolchain
- [x] A target applying `@Operation` (simulated by importing ArgumentParser through Operations) compiles without adding its own dependency

## Tests
- [x] `Tests/OperationsTests/PlaceholderTests.swift`, `Tests/OperationsMacrosTests/PlaceholderTests.swift`, `Tests/OperationsCLITests/PlaceholderTests.swift` — one trivially-true `@Test` each
- [x] Run `swift test`; expect 3 passing tests, 0 failures

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.