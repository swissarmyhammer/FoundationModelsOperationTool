import ArgumentParser
import Operations

/// Placeholder for the ArgumentParser registry driver.
///
/// `OperationCLIDriver` will assemble the noun -> verb command tree from
/// `AnyOperation` metadata at runtime (freeze-once registry, generic
/// `NounNode` leaves) and drive `ParsableCommand` parsing over it. This type
/// exists so the `OperationsCLI` target has scaffolding to build against;
/// the real driver lands in a later task.
public enum OperationsCLI {}
