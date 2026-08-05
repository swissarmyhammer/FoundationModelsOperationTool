import FoundationModelsRouter

/// A `Tool` that can produce a per-session instance of itself, derived at
/// fork time.
///
/// Transitional shim (eventplan.md §"Phases" phase 1): Router's
/// `Hosting/ForkableTool.swift` now owns this vocabulary — including its
/// blanket `forked() -> any Tool { self }` default. This re-exports its
/// canonical definition so the siblings keep compiling against one shared
/// type. The shim dies with `FoundationModelsOperationTool` in phase 5.
public typealias ForkableTool = FoundationModelsRouter.ForkableTool
