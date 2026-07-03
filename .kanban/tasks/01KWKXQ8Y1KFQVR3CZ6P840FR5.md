---
comments:
- actor: wballard
  id: 01kwm8k37y6z4nwsx56fpjc4jp
  text: |-
    Implemented. Added two tests to Tests/OperationsTests/OperationToolTests.swift in the "MARK: - Key-alias normalization" section:

    1. `keyAliasResolvesLabelsAliasToTagsCanonicalName` (after `keyAliasResolvesDeclaredAliasToCanonicalName`) — sends `labels: ["errands"]` (tags' declared alias) and asserts it resolves into the `tags` field.
    2. `explicitCanonicalKeyIsNeverOverriddenByANormalizedKeyMatch` (after `explicitCanonicalKeyIsNeverOverriddenByAnAlias`) — sends both `authorName` (canonical) and `author_name` (unaliased snake_case normalization match) and asserts the canonical `authorName` value wins.

    No production code was touched (verified via `git diff --stat` — only the test file + .kanban bookkeeping changed).

    Verification: `swift build` clean (zero warnings), `swift test` green — 22 tests / 4 suites at the top-level package, full multi-target run also green (74/34/44/22 across all suites), both new tests confirmed passing by name. Adversarial double-check agent reviewed the diff and returned PASS with no findings — confirmed the tests genuinely isolate the alias-exact and canonical-exact-vs-canonical-normalized branches of `matchingKey`'s priority order, not just incidentally passing.

    Leaving in doing per implement workflow — ready for /review.
  timestamp: 2026-07-03T15:12:11.006822+00:00
position_column: done
position_ordinal: '9680'
title: Add tests for OperationToolTests' untested key-alias precedence cases (tags/labels, authorName/author_name)
---
Surfaced by /review while working task ^zpmz5v3 (decodingFailed corrective-return path test) — pre-existing gaps in Tests/OperationsTests/OperationToolTests.swift, unrelated to that task's scope.

1. `AddNoteToolFixture.parameterMetadata` declares `tags` with alias `"labels"` (Tests/OperationsTests/OperationToolTests.swift), but no test exercises `labels` resolving to `tags` — only the `title`/`name` alias pair is tested (`keyAliasResolvesDeclaredAliasToCanonicalName`). Add a parallel test asserting `{"op": "add note", "title": ..., "labels": [...]}` resolves into the `tags` field.

2. `explicitCanonicalKeyIsNeverOverriddenByAnAlias` verifies canonical-wins-over-alias for `title`/`name`, but the same canonical-vs-normalized-key precedence isn't verified for `authorName` (canonical) vs `author_name` (snake_case, unaliased normalization match) when both are present in one payload. Add a test supplying both `authorName` and `author_name` and asserting the canonical `authorName` value wins.

Both exercise `OperationResolver.resolveParameters`'s `matchingKey` priority order (canonical exact > alias exact > canonical normalized > alias normalized) — do not modify production code, only add tests, per this board's coverage-backfill convention.