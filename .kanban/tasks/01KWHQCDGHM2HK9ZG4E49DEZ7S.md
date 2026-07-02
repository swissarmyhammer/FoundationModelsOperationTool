---
position_column: todo
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
- [ ] `swift build && swift test` run headlessly from a clean checkout (SwiftPM only — no Xcode project, no GUI)
- [ ] One placeholder test passes in each of the three test targets
- [ ] `Package.swift` pins swift-argument-parser `from: "1.8.0"` and swift-syntax matching the toolchain
- [ ] A target applying `@Operation` (simulated by importing ArgumentParser through Operations) compiles without adding its own dependency

## Tests
- [ ] `Tests/OperationsTests/PlaceholderTests.swift`, `Tests/OperationsMacrosTests/PlaceholderTests.swift`, `Tests/OperationsCLITests/PlaceholderTests.swift` — one trivially-true `@Test` each
- [ ] Run `swift test`; expect 3 passing tests, 0 failures

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.