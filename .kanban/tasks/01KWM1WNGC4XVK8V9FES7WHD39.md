---
position_column: todo
position_ordinal: '8e80'
title: Fix misleading name on fallbackLeafRoundTripsToTheSamePayloadTheResolverAccepts
---
Discovered by the local review engine while working ^qtfg8ry (unrelated to that task's diff — this test predates it).

Tests/OperationsCLITests/CLIDriverTests.swift's `CLIDriverFallbackLeafTests.fallbackLeafRoundTripsToTheSamePayloadTheResolverAccepts()` test name claims a round-trip ("RoundTrips" in the name), but the body only exercises one direction: driving `driver.run(arguments:)` and checking the printed JSON contains the expected field. It never parses the JSON output back and confirms it round-trips to the same payload the resolver would accept.

Either rename the test to describe what it actually asserts (e.g. `fallbackLeafProducesTheExpectedJSONFields`), or extend it to actually parse the output JSON and verify the round-trip claim the name makes.