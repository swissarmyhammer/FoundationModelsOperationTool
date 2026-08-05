import FoundationModelsRouter

/// How a completed operation run ended.
///
/// Transitional shim (eventplan.md §"Phases" phase 1): Router's
/// `Hosting/OperationOutcome.swift` now owns this vocabulary. This
/// re-exports its canonical definition so the siblings keep compiling
/// against one shared type. The shim dies with
/// `FoundationModelsOperationTool` in phase 5.
public typealias OperationOutcome = FoundationModelsRouter.OperationOutcome
