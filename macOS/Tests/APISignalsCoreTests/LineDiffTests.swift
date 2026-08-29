import XCTest
@testable import APISignalsCore

final class LineDiffTests: XCTestCase {

    // MARK: - Identical strings produce only unchanged lines

    func testIdenticalStrings() {
        let diff = LineDiff.diff(old: "hello\nworld", new: "hello\nworld")
        let unchanged = diff.filter { if case .unchanged = $0 { return true }; return false }
        XCTAssertEqual(unchanged.count, 2)
        XCTAssertTrue(diff.allSatisfy { if case .unchanged = $0 { return true }; return false })
    }

    // MARK: - Empty old produces only additions

    func testEmptyOld() {
        let diff = LineDiff.diff(old: "", new: "line1\nline2")
        let added = diff.filter { if case .added = $0 { return true }; return false }
        XCTAssertEqual(added.count, 2)
    }

    // MARK: - Empty new produces only removals

    func testEmptyNew() {
        let diff = LineDiff.diff(old: "line1\nline2", new: "")
        let removed = diff.filter { if case .removed = $0 { return true }; return false }
        XCTAssertEqual(removed.count, 2)
    }

    // MARK: - Single line added

    func testSingleLineAdded() {
        let diff = LineDiff.diff(old: "a\nb", new: "a\nc\nb")
        let added = diff.compactMap { if case .added(let s) = $0 { return s }; return nil }
        XCTAssertEqual(added, ["c"])
    }

    // MARK: - Single line removed

    func testSingleLineRemoved() {
        let diff = LineDiff.diff(old: "a\nc\nb", new: "a\nb")
        let removed = diff.compactMap { if case .removed(let s) = $0 { return s }; return nil }
        XCTAssertEqual(removed, ["c"])
    }

    // MARK: - Line replaced

    func testLineReplaced() {
        let diff = LineDiff.diff(old: "a\nb\nc", new: "a\nX\nc")
        let added = diff.compactMap { if case .added(let s) = $0 { return s }; return nil }
        let removed = diff.compactMap { if case .removed(let s) = $0 { return s }; return nil }
        XCTAssertEqual(added, ["X"])
        XCTAssertEqual(removed, ["b"])
    }

    // MARK: - Unchanged lines are preserved in order

    func testUnchangedOrder() {
        let diff = LineDiff.diff(old: "1\n2\n3", new: "1\n2\n3")
        let lines = diff.compactMap { if case .unchanged(let s) = $0 { return s }; return nil }
        XCTAssertEqual(lines, ["1", "2", "3"])
    }

    // MARK: - Multiple additions at end

    func testAppendLines() {
        let diff = LineDiff.diff(old: "a", new: "a\nb\nc")
        let added = diff.compactMap { if case .added(let s) = $0 { return s }; return nil }
        XCTAssertEqual(added, ["b", "c"])
    }

    // MARK: - Both empty

    func testBothEmpty() {
        let diff = LineDiff.diff(old: "", new: "")
        XCTAssertTrue(diff.isEmpty || diff.allSatisfy { if case .unchanged(let s) = $0 { return s.isEmpty }; return false })
    }

    // MARK: - JSON-like content

    func testJSONDiff() {
        let old = """
        {
          "name": "Alice",
          "age": 30
        }
        """
        let new = """
        {
          "name": "Bob",
          "age": 30
        }
        """
        let diff = LineDiff.diff(old: old, new: new)
        let added = diff.compactMap { if case .added(let s) = $0 { return s }; return nil }
        let removed = diff.compactMap { if case .removed(let s) = $0 { return s }; return nil }
        XCTAssertTrue(added.contains(where: { $0.contains("Bob") }))
        XCTAssertTrue(removed.contains(where: { $0.contains("Alice") }))
    }
}
