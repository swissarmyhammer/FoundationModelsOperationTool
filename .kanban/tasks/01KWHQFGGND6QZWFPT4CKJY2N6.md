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
depends_on:
- 01KWHQF34NAPP22345P7GMWY2P
position_column: doing
position_ordinal: '80'
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