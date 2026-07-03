---
comments:
- actor: wballard
  id: 01kwkvec47zvedxt5w218jr258
  text: |-
    Implemented. Added 4 new @Test methods to Tests/OperationsTests/OperationToolTests.swift (end of OperationToolTests suite), calling OperationResolver.matchOpString and OperationResolver.OpCandidate directly via the file's existing @testable import Operations — no production code touched:

    - matchOpStringSingleTokenExactlyMatchingACandidatesOwnSingleTokenFormReturnsIt: "addnote" (1 token) matches a candidate whose own opString is also "addnote".
    - matchOpStringSingleTokenWithNoEquivalentCandidateReturnsNil: "frobnicate" (1 token) matches nothing, returns nil.
    - matchOpStringThreeTokensExactlyMatchingACandidatesEquivalentTokenizationReturnsIt: "add the note" (3 tokens) matches a candidate opString "add_the_note" (tokenizes via `_` separator to the same 3 tokens).
    - matchOpStringThreeTokensWithNoEquivalentCandidateReturnsNil: "add the note" (3 tokens) against candidates with no equivalent tokenization, returns nil.

    These directly exercise the guard tokens.count == 2 else fallback branch in matchOpString (previously uncovered lines). Verified via `rm -rf .build && swift build && swift test`: clean build, zero warnings, zero errors; all 4 test targets green — 66+30+27+22 = 145 tests total, 0 failures. Local /review engine: 0 findings. Adversarial double-check agent: PASS, confirmed diff is test-only and each assertion genuinely traces through the fallback branch (hand-verified against spaceSeparatedTokens' lowercase/`_`/`-` separator behavior).

    Leaving task in doing for /review.
  timestamp: 2026-07-03T11:22:24.775133+00:00
position_column: doing
position_ordinal: '80'
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