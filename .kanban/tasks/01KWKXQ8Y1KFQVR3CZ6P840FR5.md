---
position_column: todo
position_ordinal: 8d80
title: Add tests for OperationToolTests' untested key-alias precedence cases (tags/labels, authorName/author_name)
---
Surfaced by /review while working task ^zpmz5v3 (decodingFailed corrective-return path test) — pre-existing gaps in Tests/OperationsTests/OperationToolTests.swift, unrelated to that task's scope.

1. `AddNoteToolFixture.parameterMetadata` declares `tags` with alias `"labels"` (Tests/OperationsTests/OperationToolTests.swift), but no test exercises `labels` resolving to `tags` — only the `title`/`name` alias pair is tested (`keyAliasResolvesDeclaredAliasToCanonicalName`). Add a parallel test asserting `{"op": "add note", "title": ..., "labels": [...]}` resolves into the `tags` field.

2. `explicitCanonicalKeyIsNeverOverriddenByAnAlias` verifies canonical-wins-over-alias for `title`/`name`, but the same canonical-vs-normalized-key precedence isn't verified for `authorName` (canonical) vs `author_name` (snake_case, unaliased normalization match) when both are present in one payload. Add a test supplying both `authorName` and `author_name` and asserting the canonical `authorName` value wins.

Both exercise `OperationResolver.resolveParameters`'s `matchingKey` priority order (canonical exact > alias exact > canonical normalized > alias normalized) — do not modify production code, only add tests, per this board's coverage-backfill convention.