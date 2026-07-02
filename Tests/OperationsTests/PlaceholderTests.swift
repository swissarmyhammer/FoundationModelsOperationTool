import Testing

@testable import Operations

/// Trivially-true placeholder confirming the `OperationsTests` target
/// builds and runs against `Operations`.
@Test func placeholderPasses() {
    #expect(true)
}

/// Confirms `Operations` re-exports `ArgumentParser`: this target declares
/// no dependency on swift-argument-parser of its own, yet `ParsableCommand`
/// is visible purely through `import Operations`. This is the mechanism
/// `@Operation`'s macro-generated `Command` types rely on.
@Test func argumentParserIsVisibleThroughOperations() {
    let commandType: ParsableCommand.Type? = nil
    #expect(commandType == nil)
}
