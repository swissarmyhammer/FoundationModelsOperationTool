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
- actor: wballard
  id: 01kwm4kswhwe6q9vr3xwkc31ef
  text: |-
    Addressed both open review findings: renamed the bare-adjective `confirmed: Bool` to `isConfirmed` in Tests/OperationsCLITests/CLIDriverTests.swift for both ArchiveNoteCLIOutput and ArchiveNoteCLIFixture.

    - ArchiveNoteCLIOutput: added a private `CodingKeys` enum mapping `isConfirmed` -> wire key `"confirmed"`, so JSONEncoder's synthesized output still emits `"confirmed":true/false` (the two new tests fallbackLeafBooleanFlagPresenceSetsTheFieldTrue/AbsenceLeavesTheFieldFalse assert on that wire-level key unchanged).
    - ArchiveNoteCLIFixture: renamed the stored property only. `ParamMeta(name: "confirmed", ...)` already separates the wire/CLI name from the Swift property name, so no change was needed there — it continues to drive the `--confirmed` CLI flag. Updated `init(_ content:)`, `generatedContent`, and `execute(in:)` to reference `isConfirmed`.

    Verified clean: `swift build` (zero warnings, exit 0) and `swift test` (160 tests across 4 batches: 72+30+36+22, zero failures, zero warnings). Checked off both checklist items in the description. Leaving task in `doing` for /review per the implement skill.
  timestamp: 2026-07-03T14:02:39.889079+00:00
- actor: wballard
  id: 01kwm4q3p47er4pyx72rhc0neg
  text: 'Round-2 verification (independent, by test agent): clean-rebuilt `.build`, ran `swift build` (exit 0, zero warnings) and `swift test` (exit 0, zero warnings, zero failures). Test run breakdown: 72 tests/6 suites + 30 tests/3 suites + 36 tests/9 suites + 22 tests/4 suites = 160 tests total, all passed. Confirmed `FallbackOperationCommandRunTests.runPrintsTheSameJSONOperationPayloadWouldProduce` (which exercises `ArchiveNoteCLIFixture`/`ArchiveNoteCLIOutput` and the `isConfirmed` -> `"confirmed"` CodingKeys wire mapping) is present and passing. No production code changes were needed.'
  timestamp: 2026-07-03T14:04:28.228811+00:00
position_column: done
position_ordinal: '9280'
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

## Review Findings (2026-07-03 08:44)

Retracted 2026-07-03: the sole finding recorded here (`CLIDriverTests.swift:164`, re the `fallbackLeafRoundTripsToTheSamePayloadTheResolverAccepts` naming/behavior mismatch) targeted pre-existing test code not touched by this task's commit fc8121f (verified via `git show fc8121f -- Tests/OperationsCLITests/CLIDriverTests.swift` — the diff only adds new tests and fixture fields; the RoundTrips test is untouched). The "never refactor existing tests" exception should have applied and dropped it; it is already tracked separately on ^s7whd39 (01KWM1WNGC4XVK8V9FES7WHD39). Recorded in error here; removed.

## Review Findings (2026-07-03 08:50)

- [x] `Tests/OperationsCLITests/CLIDriverTests.swift:79` — Boolean property 'confirmed' is a bare adjective; should use 'is' prefix. Non-mutating Boolean members must read as assertions about the receiver. Rename to `let isConfirmed: Bool` (use `@CodingKeys` if JSON key must stay `confirmed`).
- [x] `Tests/OperationsCLITests/CLIDriverTests.swift:110` — Boolean property 'confirmed' is a bare adjective; should use 'is' prefix. Non-mutating Boolean members must read as assertions about the receiver. Rename to `var isConfirmed: Bool`.

(Both `confirmed` properties are new in commit fc8121f — `ArchiveNoteCLIOutput.confirmed` and `ArchiveNoteCLIFixture.confirmed` — so the "never refactor existing tests" exception does not apply to these two; they are in-scope. 8 other findings from this pass (pinned/urgent naming, JSON/FD acronym casing) targeted pre-existing, untouched test code and were dropped per that exception.)

## Resolution (2026-07-03)

Both findings fixed: renamed `confirmed` → `isConfirmed` in both `ArchiveNoteCLIOutput` (with an explicit `CodingKeys` mapping `isConfirmed` to the wire-level JSON key `"confirmed"`) and `ArchiveNoteCLIFixture` (Swift property only — `ParamMeta.name`, the CLI flag `--confirmed`, and the `generatedContent`/`init(_:)` wire-level string literals all stay `"confirmed"`, since `ParamMeta.name` already is the wire-name/property-name split point). Updated `init(_ content:)`, `generatedContent`, and `execute(in:)` references accordingly. The four tests added by this task's commit (`fallbackLeafBooleanFlagPresenceSetsTheFieldTrue`, `fallbackLeafBooleanFlagAbsenceLeavesTheFieldFalse`, and the two inline-equals/short-flag tests) needed no assertion changes — they assert on the wire-level `--confirmed` flag and `"confirmed"` JSON key, which are unchanged.

Verification: `swift build` clean (zero warnings, exit 0). `swift test` all green — 72+30+36+22 = 160 tests across 4 batches, zero failures, zero warnings.

## Review Findings (2026-07-03 09:06)

Scope: `HEAD~1..HEAD` (checkpoint commit 93fc436, "refactor(tests): rename confirmed to isConfirmed with wire-name mapping").

Retracted 2026-07-03: all 4 findings from this pass targeted pre-existing test code not touched by this checkpoint's commit (verified via `git diff HEAD~1..HEAD -- Tests/OperationsCLITests/CLIDriverTests.swift` — the diff only touches `ArchiveNoteCLIOutput`/`ArchiveNoteCLIFixture`'s `confirmed`→`isConfirmed` rename, around lines 79-135). The findings below concern `AddNoteCLIFixture`/`AddNoteCLIOutput`'s `pinned`/`urgent` Boolean properties (lines 18, 19, 39, 43), which predate this checkpoint and are unrelated to its diff — the same category of pre-existing-code finding already dropped in the 08:50 pass above. Per the "never refactor existing tests" exception (and the instruction to scope this review to the checkpoint delta only), dropped as out-of-scope; not yet tracked separately.

- `Tests/OperationsCLITests/CLIDriverTests.swift:18` — Boolean property `pinned` is a bare adjective; non-mutating Boolean members must read as assertions per the naming convention shown elsewhere in this file. Rename to `isPinned`. If the wire format must remain `pinned`, add a `CodingKeys` mapping like the one at lines 79–83.
- `Tests/OperationsCLITests/CLIDriverTests.swift:19` — Boolean property `urgent` is a bare adjective; non-mutating Boolean members must read as assertions per the naming convention shown elsewhere in this file. Rename to `isUrgent`. If the wire format must remain `urgent`, add a `CodingKeys` mapping like the one at lines 79–83.
- `Tests/OperationsCLITests/CLIDriverTests.swift:39` — Boolean property `pinned` is a bare adjective; non-mutating Boolean members must read as assertions per the naming convention shown elsewhere in this file. Rename to `isPinned`.
- `Tests/OperationsCLITests/CLIDriverTests.swift:43` — Boolean property `urgent` is a bare adjective; non-mutating Boolean members must read as assertions per the naming convention shown elsewhere in this file. Rename to `isUrgent`.

No in-scope findings for this checkpoint delta. All prior checklist items are checked.