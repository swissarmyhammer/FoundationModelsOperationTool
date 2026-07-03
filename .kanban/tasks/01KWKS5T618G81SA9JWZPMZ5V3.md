---
comments:
- actor: wballard
  id: 01kwkxqjwtzknd75192hn20gbz
  text: |-
    Implemented: added `DecodingFailureToolFixture` (OperationDefinition whose init(_:) unconditionally throws `FixtureDecodingError`, with a required `title` param the resolver always finds present) and the test `decodingFailedFromOperationInitReturnsCorrectiveMessageInsteadOfThrowing` to Tests/OperationsTests/OperationToolTests.swift. It builds a standalone OperationTool with just that fixture, calls with `{"op": "fail decode", "title": "Groceries"}` — resolveParameters finds no missing required params, dispatch reaches operation.run, init(_:) throws, AnyOperation.run translates to OperationError.decodingFailed, OperationTool.call catches it and returns the corrective description via recordCorrective. Asserts `message == OperationError.decodingFailed.description`.

    No production code was modified (OperationTool.swift, AnyOperation.swift, OperationError.swift left untouched).

    Verification: `rm -rf .build && swift build` — clean, zero warnings. `swift test` — all 4 targets green (71+30+27+22 = 150 tests), zero failures. `swift test --filter OperationToolTests` confirms the new test passes individually (28/28 tests in the suite).

    Ran local /review (review working) as a self-check per task instructions. It returned 2 findings, both pre-existing gaps in the same test file unrelated to this task's scope: (1) AddNoteToolFixture's `tags`/`labels` alias is untested (only `title`/`name` is), and (2) canonical-vs-snake_case precedence isn't tested for `authorName`/`author_name` the way it is for `title`/`name`. Per this task's explicit scope ("only add a test" for the decodingFailed path) and to avoid scope creep, I did not fix these — logged them as new task ^p840fr5 instead.

    Leaving task in doing for review, per /implement workflow (not moving to review myself).
  timestamp: 2026-07-03T12:02:23.770374+00:00
position_column: doing
position_ordinal: '80'
title: Add test for OperationTool.call's decodingFailed corrective-return path
---
Sources/Operations/OperationTool.swift:123-140 (specifically 137-139)

Coverage: 96.4% (53/55 lines)

Uncovered lines: 138-139:

```swift
public func call(arguments: GeneratedContent) async throws -> String {
    ...
    do {
        let json = try await operation.run(resolution.content, context)
        await retryState.reset()
        return json
    } catch OperationError.decodingFailed {
        return await recordCorrective(OperationError.decodingFailed.description)
    }
}
```

This is a core, documented part of plan.md's "Error handling — return, don't throw" contract: when the resolved payload passes parameter resolution but still fails to decode into the target operation's typed representation (`OperationDefinition.init(_:)` throws), `OperationTool.call` must catch `OperationError.decodingFailed` from `AnyOperation.run` and return a corrective string rather than throwing — so the model can retry within the turn. This path is currently completely untested. Add a test with a fixture operation whose `init(_:)` deliberately throws on a resolvable-but-malformed payload, and assert `call(arguments:)` returns the corrective text (not a thrown error).