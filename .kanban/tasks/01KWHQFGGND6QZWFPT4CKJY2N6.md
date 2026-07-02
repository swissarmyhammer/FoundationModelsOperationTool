---
depends_on:
- 01KWHQF34NAPP22345P7GMWY2P
position_column: todo
position_ordinal: '8780'
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