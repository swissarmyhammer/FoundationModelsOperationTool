---
position_column: todo
position_ordinal: '8980'
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