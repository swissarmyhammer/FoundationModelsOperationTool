# FoundationModelsOperations

[![CI](https://github.com/swissarmyhammer/FoundationModelsOperationTool/actions/workflows/ci.yml/badge.svg)](https://github.com/swissarmyhammer/FoundationModelsOperationTool/actions/workflows/ci.yml)

Declare a typed operation once with `@Operation`, and get both a fused
[FoundationModels](https://developer.apple.com/documentation/foundationmodels) `Tool` and a dual-use
command-line verb for free. A struct's stored properties *are* its parameters; behavior lives in a
separate `execute(in:)` — the same metadata/behavior split as [swissarmyhammer](../swissarmyhammer)'s
Rust operation-tool pattern.

<!-- doc-snippet source="Examples/NotesTool/Sources/NotesToolCore/AddNote.swift" -->
```swift
/// Creates a new note, per plan.md's "Declaring an operation" example.
@Generable
@Operation(verb: "add", noun: "note", description: "Create a new note")
internal struct AddNote {
    @Guide(description: "The note title")
    @OperationParam(short: "t")
    var title: String

    @Guide(description: "Markdown body of the note")
    @OperationParam(short: "b")
    var body: String?

    @Guide(description: "Tags to attach")
    var tags: [String]?
}

extension AddNote {
    func execute(in context: NotesContext) async throws -> Note {
        await context.store.insert(title: title, body: body, tags: tags ?? [])
    }
}
```
<!-- /doc-snippet -->

`@Operation`'s expansion also emits a nested `Command: AsyncParsableCommand`, so the same
declaration drives `notes note add --title "Groceries" --tags errands` from the command line,
converging on the identical payload the model would have sent.

## Install

Add the package (Swift 6.2 tools, macOS 26 / iOS 26 SDK — FoundationModels availability):

```swift
.package(url: "https://github.com/swissarmyhammer/FoundationModelsOperationTool.git", branch: "main")
```

## Documentation

The full guide — fusing operations into a `Tool`, registering with a `LanguageModelSession`, and the
dual-use CLI — is in [`docs/GUIDE.md`](docs/GUIDE.md). Design rationale, including the evidence behind
the schema-fusion decision and where the implementation departed from the original plan, is in
[`plan.md`](plan.md) and [`DESIGN_NOTES.md`](DESIGN_NOTES.md).
