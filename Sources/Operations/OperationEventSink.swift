import FoundationModelsRouter

/// A destination `OperationEvent`s are posted to.
///
/// Transitional shim (eventplan.md §"Phases" phase 1): Router's
/// `Hosting/OperationEventSink.swift` now owns this vocabulary. This
/// re-exports its canonical definition so the siblings keep compiling
/// against one shared type. The shim dies with
/// `FoundationModelsOperationTool` in phase 5.
public typealias OperationEventSink = FoundationModelsRouter.OperationEventSink
