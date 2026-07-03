---
position_column: todo
position_ordinal: '8280'
title: Add test for OperationResolver.matchOpString's non-two-token fallback path
---
Sources/Operations/OperationResolver.swift:93-97

Coverage: 94.8% (73/77 lines)

Uncovered lines: 96-97, inside `matchOpString(_:against:)`:

```swift
internal func matchOpString(_ opString: String, against candidates: [OpCandidate]) -> String? {
    let tokens = Self.spaceSeparatedTokens(opString)
    guard tokens.count == 2 else {
        let joined = tokens.joined(separator: " ")
        return candidates.first { Self.spaceSeparatedTokens($0.opString).joined(separator: " ") == joined }?.opString
    }
    ...
}
```

Every existing test supplies an opString that tokenizes to exactly 2 words (verb + noun), so the `guard tokens.count == 2 else` branch — the exact-joined-token fallback for a 1-token or 3+-token opString (e.g. `"addnote"` with no separator, or `"add the note"`) — is never exercised. Add tests covering both a single-token opString that exactly matches a candidate's own single-token-equivalent form, and one that doesn't match (returns nil).