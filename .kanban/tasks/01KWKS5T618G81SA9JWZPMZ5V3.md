---
position_column: todo
position_ordinal: '8480'
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