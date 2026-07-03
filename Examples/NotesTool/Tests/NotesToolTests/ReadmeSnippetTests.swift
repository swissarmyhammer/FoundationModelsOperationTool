import Foundation
import Testing

/// Verifies plan.md task 8's "README examples compile" acceptance criterion:
/// every `<!-- doc-snippet source="..." --> ``` ... ``` <!-- /doc-snippet -->`
/// code block in the repo root's `README.md` is a genuine, contiguous excerpt
/// of the source file it cites, not hand-written pseudocode that could drift
/// out of sync with what actually compiles.
///
/// Placed in `NotesToolTests` (rather than `OperationsTests`, alongside
/// `DocCoverageTests.swift`) because every README snippet is cited from
/// `Examples/NotesTool` — the worked example this test suite already covers
/// end to end.
@Suite("README code-snippet provenance")
struct ReadmeSnippetTests {
    @Test("every README code snippet is a real, contiguous excerpt of its cited source file")
    func everySnippetIsARealContiguousExcerptOfItsSource() throws {
        let snippets = try ReadmeSnippets.parse(readmeContents())
        #expect(!snippets.isEmpty, "expected README.md to contain at least one <!-- doc-snippet --> block")

        for snippet in snippets {
            let sourceLines = try sourceFileLines(relativePath: snippet.sourcePath)
            #expect(
                ReadmeSnippets.isContiguousExcerpt(snippet.code, of: sourceLines),
                Comment(rawValue: "README snippet citing '\(snippet.sourcePath)' is not a contiguous excerpt of that file")
            )
        }
    }

    @Test("a doc-snippet source path that escapes the package root is rejected")
    func sourcePathOutsideThePackageRootIsRejected() {
        #expect(throws: (any Error).self) {
            _ = try sourceFileLines(relativePath: "../../../../../../etc/passwd")
        }
    }

    @Test("the README documents all four declare/fuse/serve/CLI stages from real NotesTool source")
    func readmeDocumentsAllFourStages() throws {
        let snippets = try ReadmeSnippets.parse(readmeContents())
        let sourcePaths = Set(snippets.map(\.sourcePath))

        #expect(sourcePaths.contains("Examples/NotesTool/Sources/NotesToolCore/AddNote.swift"))
        #expect(sourcePaths.contains("Examples/NotesTool/Sources/NotesToolCore/NotesTool.swift"))
        #expect(sourcePaths.contains("Examples/NotesTool/Sources/notes/ChatValidationHarness.swift"))
        #expect(sourcePaths.contains("Examples/NotesTool/Sources/notes/NotesToolMain.swift"))
    }

    private func readmeContents() throws -> String {
        try String(contentsOf: packageRoot().appendingPathComponent("README.md"), encoding: .utf8)
    }

    private func sourceFileLines(relativePath: String) throws -> [String] {
        let root = packageRoot()
        let fileURL = root.appendingPathComponent(relativePath)
        try requireWithinPackageRoot(fileURL, root: root)
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        return contents.components(separatedBy: "\n")
    }

    /// A source path cited by a README `doc-snippet` marker resolved outside
    /// the package root — e.g. via a `..` component.
    private struct PathEscapesPackageRoot: Error, CustomStringConvertible {
        let path: String
        var description: String { "'\(path)' resolves outside the package root" }
    }

    /// Guards against `relativePath` (via `..` or similar) resolving `url`
    /// outside `root`.
    ///
    /// - Throws: `PathEscapesPackageRoot` if `url`'s standardized path isn't
    ///   `root`'s standardized path or a descendant of it.
    private func requireWithinPackageRoot(_ url: URL, root: URL) throws {
        let standardizedURL = url.standardizedFileURL.path
        let standardizedRoot = root.standardizedFileURL.path
        guard standardizedURL == standardizedRoot || standardizedURL.hasPrefix(standardizedRoot + "/") else {
            throw PathEscapesPackageRoot(path: standardizedURL)
        }
    }

    /// The package root directory, derived from this file's own path: four
    /// levels up from `Examples/NotesTool/Tests/NotesToolTests/ReadmeSnippetTests.swift`.
    private func packageRoot(thisFile: String = #filePath) -> URL {
        URL(fileURLWithPath: thisFile)
            .deletingLastPathComponent()  // ReadmeSnippetTests.swift -> NotesToolTests/
            .deletingLastPathComponent()  // NotesToolTests/ -> Tests/
            .deletingLastPathComponent()  // Tests/ -> NotesTool/
            .deletingLastPathComponent()  // NotesTool/ -> Examples/
            .deletingLastPathComponent()  // Examples/ -> package root
    }
}

/// Parses `<!-- doc-snippet source="..." -->` blocks out of a README and
/// checks each fenced code block against the source file it cites.
enum ReadmeSnippets {
    /// One `<!-- doc-snippet -->` block: the fenced code it wraps, and the
    /// source-file path (relative to the package root) it claims to excerpt.
    struct Snippet {
        let sourcePath: String
        let code: String
    }

    /// Extracts every well-formed `doc-snippet` block from `readme`, in
    /// document order.
    ///
    /// A block is: a `<!-- doc-snippet source="PATH" -->` line, a fenced
    /// code block (` ``` ` … ` ``` `), then a `<!-- /doc-snippet -->` line.
    /// Malformed blocks (a marker with no following fence) are skipped.
    static func parse(_ readme: String) throws -> [Snippet] {
        let lines = readme.components(separatedBy: "\n")
        var snippets: [Snippet] = []
        var index = 0

        while index < lines.count {
            guard let sourcePath = sourcePath(fromMarkerLine: lines[index]) else {
                index += 1
                continue
            }
            index += 1  // past the marker line
            guard index < lines.count, lines[index].hasPrefix("```") else {
                index += 1
                continue
            }
            index += 1

            var codeLines: [String] = []
            while index < lines.count, lines[index] != "```" {
                codeLines.append(lines[index])
                index += 1
            }
            index += 1  // past the closing fence

            snippets.append(Snippet(sourcePath: sourcePath, code: codeLines.joined(separator: "\n")))
        }
        return snippets
    }

    /// The `source="..."` value from a `<!-- doc-snippet source="..." -->`
    /// line, or `nil` if `line` isn't one.
    private static func sourcePath(fromMarkerLine line: String) -> String? {
        let prefix = "<!-- doc-snippet source=\""
        guard line.hasPrefix(prefix), let closingQuote = line.range(of: "\" -->") else { return nil }
        let start = line.index(line.startIndex, offsetBy: prefix.count)
        return String(line[start..<closingQuote.lowerBound])
    }

    /// Whether `snippet`'s lines, each trimmed of leading/trailing
    /// whitespace, appear as a contiguous, in-order run somewhere in
    /// `sourceLines` (also trimmed).
    ///
    /// Comparing trimmed lines — rather than requiring byte-identical text —
    /// lets the README re-indent a snippet for readability (e.g. dedenting
    /// code excerpted from inside a deeply nested function) while still
    /// requiring it to be a genuine, ordered, contiguous excerpt of the real
    /// file, not lines cherry-picked from unrelated places or invented
    /// outright.
    static func isContiguousExcerpt(_ snippet: String, of sourceLines: [String]) -> Bool {
        let needle = snippet.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let haystack = sourceLines.map { $0.trimmingCharacters(in: .whitespaces) }
        guard !needle.isEmpty, haystack.count >= needle.count else { return false }

        for start in 0...(haystack.count - needle.count) {
            if Array(haystack[start..<(start + needle.count)]) == needle {
                return true
            }
        }
        return false
    }
}
