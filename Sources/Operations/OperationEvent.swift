import FoundationModelsRouter

/// The category of a posted `OperationEvent`: whether a long-running
/// operation is still running, has finished, or is asking the user a
/// question.
///
/// Transitional shim (eventplan.md §"Phases" phase 1): Router's
/// `Hosting/OperationEvent.swift` now owns this vocabulary. This re-exports
/// its canonical definition so the siblings keep compiling against one
/// shared type. The shim dies with `FoundationModelsOperationTool` in phase
/// 5.
public typealias OperationEventKind = FoundationModelsRouter.OperationEventKind

/// A standard progress/completion event a long-running operation posts
/// through a connected `OperationEventSink`.
///
/// Transitional shim (eventplan.md §"Phases" phase 1): Router's
/// `Hosting/OperationEvent.swift` now owns this vocabulary. This re-exports
/// its canonical definition so the siblings keep compiling against one
/// shared type. The shim dies with `FoundationModelsOperationTool` in phase
/// 5.
public typealias OperationEvent = FoundationModelsRouter.OperationEvent
