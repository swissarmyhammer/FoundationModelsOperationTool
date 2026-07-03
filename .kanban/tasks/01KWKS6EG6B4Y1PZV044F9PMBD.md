---
comments:
- actor: wballard
  id: 01kwm3e2pjvxwgh0n9xw18y3d1
  text: |-
    Implemented: extended the existing macro-less `ArchiveNoteCLIFixture` fixture in Tests/OperationsCLITests/CLIDriverTests.swift (used by CLIDriverFallbackLeafTests) rather than adding a new fixture — `reasonCode`'s ParamMeta gained `short: "r"`, and a new required `confirmed: Bool` parameter (ParamMeta type `.boolean`) was added, with ArchiveNoteCLIOutput/init(_:)/generatedContent/execute(in:) updated to match.

    Added 4 new @Test functions to CLIDriverFallbackLeafTests, each mapped to a previously-uncovered line in FallbackOperationCommand.swift:
    - fallbackLeafBooleanFlagPresenceSetsTheFieldTrue (`--confirmed` presence -> `collected.flags.insert`)
    - fallbackLeafBooleanFlagAbsenceLeavesTheFieldFalse (absence -> convertedValue's `.boolean` branch returning false)
    - fallbackLeafAcceptsTheInlineEqualsFormForAScalarParameter (`--reasonCode=42` -> splitInlineValue)
    - fallbackLeafAcceptsAShortFlagSpellingWithAValue (`-r 42` -> flagNameIndex's short-flag branch)

    Self-review via /review found one finding: the hand-written ArchiveNoteCLIFixture.generatedContent (unused elsewhere in the codebase — dead code required only by Generable conformance) only emitted `id`, so init(_:) <-> generatedContent wasn't a true round trip. This predated my change for `reasonCode` but I was extending the same gap with `confirmed`, so I fixed generatedContent to include reasonCode (conditionally) and confirmed, matching FallbackPayloadBuilder's own tuple-array style. Re-ran /review after: zero findings.

    Verification: `swift build` clean (zero warnings), `swift test` all green (72+30+36+22 tests across 4 test-run batches, zero failures). Production code Sources/OperationsCLI/FallbackOperationCommand.swift has zero diff — confirmed via git status. Adversarial double-check agent independently verified build/test green, line-to-test mapping, and fixture consistency: verdict PASS, no findings.

    Leaving task in `doing` for /review per the implement skill (not moving to review myself).
  timestamp: 2026-07-03T13:42:03.730293+00:00
position_column: doing
position_ordinal: '80'
title: Add tests for FallbackPayloadBuilder's boolean flags, inline =value, and short-flag argument parsing
---
Sources/OperationsCLI/FallbackOperationCommand.swift:106-147

Coverage: 75.2% (97/129 lines)

Uncovered lines: 110-112, 128-129, 140, 147, inside `collectRawValues`, `flagNameIndex`, `splitInlineValue`, and `convertedValue`:

```swift
if parameter.type == .boolean {
    collected.flags.insert(parameter.name)          // 110 — boolean flag presence
} else if let inlineValue {
    collected.stringValues[parameter.name, default: []].append(inlineValue)   // 111-112 — --name=value
} else if index < rawArguments.endIndex { ... }

// flagNameIndex:
if let short = parameter.short {
    index["-\(short)"] = parameter                  // 128-129 — short-flag spelling
}

// splitInlineValue:
return (String(token[token.startIndex..<equalsIndex]), String(token[token.index(after: equalsIndex)...]))  // 140

// convertedValue:
if parameter.type == .boolean {
    return collected.flags.contains(parameter.name)  // 147
}
```

`Tests/OperationsCLITests/CLIDriverTests.swift`'s macro-less-fallback-leaf coverage currently only exercises plain `--name value` string arguments. Boolean flags (`--flag` presence, no value), the `--name=value` inline-equals form, and `-x` short-flag spellings are never exercised through the fallback (macro-less) CLI path. Add CLI-driver round-trip tests for a macro-less fixture operation with a boolean parameter and a `short`-aliased parameter, covering both `--name=value` and `-x value` invocation forms.