---
comments:
- actor: wballard
  id: 01kwk6f0h8fdtyt4rg4tm5n0v6
  text: |-
    Implemented via TDD.

    **README.md** (new, repo root): package overview, package layout (Sources/Operations, OperationsMacros, OperationsCLI, Examples/NotesTool), "Declaring an operation", "Fusing operations into a Tool", "Registering with a LanguageModelSession", "The dual-use CLI", build/test instructions. Four sections embed a Swift code block wrapped in `<!-- doc-snippet source="..." -->` / `<!-- /doc-snippet -->` markers citing real files under Examples/NotesTool (AddNote.swift, NotesTool.swift, ChatValidationHarness.swift, NotesToolMain.swift) — verified as genuine, contiguous, in-order excerpts (not invented pseudocode) by a new test.

    **DESIGN_NOTES.md** (new, repo root): two sections. "Departures from the Rust swissarmyhammer design" condenses plan.md's own two documented departures (flat-union schema, ArgumentParser runtime registry) with file references. "Departures discovered during implementation" — found by mining git log + every completed task's kanban comment history — records six real deviations from plan.md's literal text: GeneratedContent built via the `properties:` initializer instead of `GeneratedContent(json:)` (avoids a Foundation import); `Command.run()` staying print-only with the CLI driver dispatching via `operationPayload()` instead; `OperationError.encodingFailed` split from `.decodingFailed` (a real bug fix); required array fields always serializing as `[]` (a real TDD-caught bug); extra-key tolerance enforced by construction in the resolver rather than left to `@Generable`'s undocumented behavior; retry-cap state living in a private `actor RetryState` for concurrency safety.

    **Doc coverage**: audited every `public` declaration in `Sources/Operations/*.swift` and `Sources/OperationsCLI/*.swift` (grep -B2 across all files) — found exactly one gap: `OperationDefinition.swift`'s `extension OperationDefinition { public static var opString ... }` (the protocol's default implementation) had no doc comment, even though the protocol *requirement* one line above it did. Added one. Everything else was already documented from prior review rounds.

    **Tests/OperationsTests/DocCoverageTests.swift + DocCoverageScannerTests.swift** (new): a SwiftSyntax-based `DocCoverageScanner` walks `Sources/Operations`/`Sources/OperationsCLI` and fails on any `public` declaration (or `case` inside a `public enum`, which carries no modifier of its own) lacking a doc comment directly attached — exactly one newline before it, no blank-line gap, tolerant of intervening attributes like `@attached(...)`. 9 unit tests against synthetic fixtures plus 2 integration tests against the real tree. Verified genuinely RED->GREEN: temporarily reverted the `opString` doc fix, confirmed the integration test failed with the exact right violation message and line number, restored the fix. Required adding SwiftSyntax + SwiftParser as OperationsTests target dependencies in Package.swift.

    **Examples/NotesTool/Tests/NotesToolTests/ReadmeSnippetTests.swift** (new): parses README.md's `doc-snippet` blocks and verifies each is a real, contiguous, in-order (per-line-trimmed, so the README can dedent for readability) excerpt of the source file it cites. Caught a real off-by-one bug in the parser itself during development (a dropped `index += 1` after a self-inflicted "fix" for an unrelated infinite-loop risk) — traced it down to the exact line via a temporary debug test, fixed, removed the debug scaffolding.

    **Review**: ran `/review` on the working diff. 2 findings addressed (both new test files' path-construction helpers hardened against `..` escaping the package root, with regression tests, even though both only ever receive hardcoded/repo-local paths — cheap to fix, so fixed rather than argued about). 2 findings deliberately left unaddressed with reasoning logged: (a) `packageRoot()` duplication between DocCoverageTests.swift and ReadmeSnippetTests.swift — the two files live in different SwiftPM test targets (OperationsTests vs NotesToolTests) with no existing shared test-support module; creating one for ~6 duplicated lines is over-engineering for a docs task. (b) Renaming the public `opString` property to `operationString` — a pre-existing identifier from an earlier, already-reviewed task, used pervasively across `Sources/Operations`, `Sources/OperationsCLI`, `Sources/OperationsMacros`, and all test/example code; renaming it is a large, unrelated, blast-radius-heavy refactor entirely outside this task's scope.

    **Verification**: `rm -rf .build && swift build` — clean, zero warnings. `swift test` — all 4 test targets green: 59 (OperationsTests) + 30 (OperationsMacrosTests) + 27 (OperationsCLITests) + 21 (NotesToolTests) = 137 tests, 0 failures. Adversarial double-check dispatched to independently verify README snippet accuracy, DESIGN_NOTES.md claims against real source, scanner/snippet-test correctness, and the two rejected-finding judgment calls.

    Leaving in `doing` for `/review`.
  timestamp: 2026-07-03T05:15:45.576002+00:00
- actor: wballard
  id: 01kwk7g97pjbza7rsas8zsnnt8
  text: |-
    Fixed the review finding: extracted the duplicated `requireWithinPackageRoot()` logic (identical in ReadmeSnippetTests.swift and DocCoverageTests.swift, differing only in thrown error type) into a genuinely shared location, superseding the earlier self-review's "no shared test-support module exists" rejection.

    **New target**: `TestSupport` — a plain SwiftPM `.target` (not `.testTarget`, since test targets can't depend on one another) at `Tests/TestSupport/PackageRootValidation.swift`, containing:
    ```swift
    public enum PackageRootValidation {
        public static func requireWithinPackageRoot<E: Error>(
            _ url: URL, root: URL, throwing onEscape: (String) -> E
        ) throws { ... }
    }
    ```
    The differing error type is handled via a generic caller-supplied closure, as the finding suggested.

    **Package.swift**: added the `TestSupport` target, and added it as a dependency of both `OperationsTests` and `NotesToolTests`.

    **DocCoverageTests.swift**: `DocCoverageScanner.scan(directory:)` now calls `PackageRootValidation.requireWithinPackageRoot(directoryURL, root: root) { ScanError.pathEscapesPackageRoot($0) }`; the private duplicate method was deleted.

    **ReadmeSnippetTests.swift**: `sourceFileLines(relativePath:)` now calls `PackageRootValidation.requireWithinPackageRoot(fileURL, root: root) { PathEscapesPackageRoot(path: $0) }`; the private duplicate method was deleted. The local `PathEscapesPackageRoot` error struct and each file's own `packageRoot()` helper (different relative depth per file) were deliberately left in place — the finding was specifically about the duplicated validation function body, not the error types or the root-finding helpers.

    Verified: `rm -rf .build && swift build` — clean, zero warnings. `swift test` — all 4 test targets green, same 137 tests as before (59 + 30 + 27 + 21), 0 failures, including both escape-rejection regression tests (`scanningADirectoryOutsideThePackageRootThrows`, `sourcePathOutsideThePackageRootIsRejected`). Adversarial double-check agent independently confirmed: target wiring correct, duplication genuinely eliminated (not relocated in a different form), no lingering duplicate copies elsewhere in the repo, build/test clean, no scope creep. Verdict: PASS.

    Both checklist items for this finding are now checked off. Leaving in `doing` for `/review`.
  timestamp: 2026-07-03T05:33:55.830127+00:00
depends_on:
- 01KWHQF34NAPP22345P7GMWY2P
position_column: done
position_ordinal: '8880'
title: 'Docs: README + DocC on public API, record design departures'
---
## What
Per plan.md task 8: `README.md` walking declare → fuse → serve → CLI in four code blocks (mirroring the NotesTool example so the snippets are real); DocC comments on all public API in `Sources/Operations/` and `Sources/OperationsCLI/`; a short "Design notes" section recording the departures from the Rust swissarmyhammer design and why (flat-union schema + evidence pointers, return-don't-throw tool errors, ArgumentParser runtime registry, scale guidance of ~5–15 ops per tool).

## Acceptance Criteria
- [ ] README code blocks compile — sourced from or verified against the NotesTool example target
- [ ] Every `public` symbol in `Sources/Operations/` and `Sources/OperationsCLI/` has a `///` doc block, enforced by an automated check (doc-coverage test that scans the source, or DocC build with `--warnings-as-errors` wired into `swift test`/CI)
- [ ] plan.md remains as the design record; README links to it

## Tests
- [ ] Doc-coverage test: `Tests/OperationsTests/DocCoverageTests.swift` walks the two source directories and fails on any `public` declaration without a preceding `///` block
- [ ] Doc-snippet verification: a test asserts README example code exists as compiled code in `Examples/NotesTool`
- [ ] Run `swift build && swift test`; green

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-07-03 00:22)

- [x] `Examples/NotesTool/Tests/NotesToolTests/ReadmeSnippetTests.swift:71` — The `requireWithinPackageRoot()` function duplicates nearly identical logic from `DocCoverageTests.swift:176`. Both implement identical path validation (standardization and prefix checking), differing only in error type. Identical validation logic across test files means fixes must happen in two places. Extract the shared path validation logic into a single location (e.g., a test utility or extension on URL) that both call sites reuse, parameterizing the error type or wrapping each error type at the call site.
- [x] `Tests/OperationsTests/DocCoverageTests.swift:176` — The `requireWithinPackageRoot()` function duplicates nearly identical logic from `ReadmeSnippetTests.swift:71`. Both implement identical path validation (standardization and prefix checking), differing only in error type. Identical validation logic across test files means fixes must happen in two places. Extract the shared path validation logic into a single location (e.g., a test utility or extension on URL) that both call sites reuse, parameterizing the error type or wrapping each error type at the call site.