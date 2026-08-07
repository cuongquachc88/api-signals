import Foundation

public enum JSONFormatError: Error, Equatable, Sendable {
    case empty
    case invalid(String, line: Int?, column: Int?, utf16Offset: Int?)

    public var message: String {
        switch self {
        case .empty:
            return "JSON is empty"
        case .invalid(let detail, let line, let column, _):
            if let line, let column {
                return "Line \(line), column \(column): \(detail)"
            }
            if let line {
                return "Line \(line): \(detail)"
            }
            return detail
        }
    }

    public var line: Int? {
        if case .invalid(_, let line, _, _) = self { return line }
        return nil
    }

    public var column: Int? {
        if case .invalid(_, _, let column, _) = self { return column }
        return nil
    }

    public var utf16Offset: Int? {
        if case .invalid(_, _, _, let offset) = self { return offset }
        return nil
    }

    public static func invalid(_ detail: String) -> JSONFormatError {
        .invalid(detail, line: nil, column: nil, utf16Offset: nil)
    }
}

/// Result of validating a JSON document.
public struct JSONValidationResult: Equatable, Sendable {
    public let isValid: Bool
    public let error: JSONFormatError?

    public var message: String? { error?.message }
    public var line: Int? { error?.line }
    public var column: Int? { error?.column }
    public var utf16Offset: Int? { error?.utf16Offset }

    public static let valid = JSONValidationResult(isValid: true, error: nil)

    public static func failure(_ error: JSONFormatError) -> JSONValidationResult {
        JSONValidationResult(isValid: false, error: error)
    }
}

public enum JSONFormatter {
    /// Pretty-print threshold above which key sorting is skipped (much faster on large objects).
    public static let largeJSONCharacterThreshold = 80_000

    /// Pretty-print JSON with 2-space indent.
    /// - Parameter sortedKeys: defaults to `true` for small payloads; pass `false` for large JSON.
    public static func beautify(_ text: String, sortedKeys: Bool? = nil) throws -> String {
        let object = try parse(text)
        let shouldSort = sortedKeys ?? (text.count < largeJSONCharacterThreshold)
        var options: JSONSerialization.WritingOptions = [.prettyPrinted, .withoutEscapingSlashes]
        if shouldSort { options.insert(.sortedKeys) }
        let data = try JSONSerialization.data(withJSONObject: object, options: options)
        guard let result = String(data: data, encoding: .utf8) else {
            throw JSONFormatError.invalid("Could not encode JSON")
        }
        return result
    }

    /// Compact JSON onto a single line.
    public static func minify(_ text: String) throws -> String {
        let object = try parse(text)
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.withoutEscapingSlashes]
        )
        guard let result = String(data: data, encoding: .utf8) else {
            throw JSONFormatError.invalid("Could not encode JSON")
        }
        return result
    }

    /// Validates JSON. Returns `nil` when valid (or empty).
    public static func validate(_ text: String) -> JSONFormatError? {
        validateDetailed(text).error
    }

    /// Full validation result including line/column when available.
    public static func validateDetailed(_ text: String) -> JSONValidationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .failure(.empty)
        }
        do {
            _ = try parse(text)
            return .valid
        } catch let error as JSONFormatError {
            return .failure(error)
        } catch {
            return .failure(.invalid(error.localizedDescription))
        }
    }

    public static func isValid(_ text: String) -> Bool {
        let result = validateDetailed(text)
        return result.isValid || result.error == .empty
    }

    private static func parse(_ text: String) throws -> Any {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw JSONFormatError.empty }
        guard let data = trimmed.data(using: .utf8) else {
            throw JSONFormatError.invalid("Invalid UTF-8")
        }
        do {
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw makeInvalidError(from: error, in: text)
        }
    }

    private static func makeInvalidError(from error: Error, in text: String) -> JSONFormatError {
        let ns = error as NSError
        var detail = simplifiedMessage(from: ns)
        let (line, column) = extractLineColumn(from: detail) ?? (nil, nil)
        // Prefer a cleaner message without duplicated location prefix when we surface it separately.
        detail = stripLocationPrefix(from: detail)
        let offset = utf16Offset(in: text, line: line, column: column)
        return .invalid(detail, line: line, column: column, utf16Offset: offset)
    }

    private static func simplifiedMessage(from ns: NSError) -> String {
        if let debug = ns.userInfo[NSDebugDescriptionErrorKey] as? String, !debug.isEmpty {
            return debug
        }
        return ns.localizedDescription
    }

    /// Parses "around line N, column M" / "line N column M" style locations from Foundation errors.
    private static func extractLineColumn(from message: String) -> (Int, Int)? {
        let patterns = [
            #"(?i)line\s+(\d+)\s*,\s*column\s+(\d+)"#,
            #"(?i)line\s+(\d+)\s+column\s+(\d+)"#,
            #"(?i)line\s+(\d+)"#
        ]
        for (index, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(message.startIndex..<message.endIndex, in: message)
            guard let match = regex.firstMatch(in: message, range: range) else { continue }
            guard match.numberOfRanges >= 2,
                  let lineRange = Range(match.range(at: 1), in: message),
                  let line = Int(message[lineRange]) else { continue }
            if index < 2, match.numberOfRanges >= 3,
               let colRange = Range(match.range(at: 2), in: message),
               let column = Int(message[colRange]) {
                return (line, column)
            }
            return (line, 1)
        }
        return nil
    }

    private static func stripLocationPrefix(from message: String) -> String {
        // "Invalid value around line 1, column 5." -> keep useful head when possible
        var result = message
        if let regex = try? NSRegularExpression(pattern: #"(?i)\s*around\s+line\s+\d+(?:\s*,\s*column\s+\d+)?"#) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasSuffix(".") { result.removeLast() }
        return result.isEmpty ? message : result
    }

    /// Converts 1-based line/column into a UTF-16 offset into `text`.
    public static func utf16Offset(in text: String, line: Int?, column: Int?) -> Int? {
        guard let line, line > 0 else { return nil }
        let ns = text as NSString
        var currentLine = 1
        var index = 0
        let length = ns.length
        while index < length && currentLine < line {
            let ch = ns.character(at: index)
            index += 1
            if ch == 10 { // \n
                currentLine += 1
            } else if ch == 13 { // \r
                if index < length && ns.character(at: index) == 10 { index += 1 }
                currentLine += 1
            }
        }
        guard currentLine == line else {
            return max(0, length - 1)
        }
        let col = max((column ?? 1) - 1, 0)
        return min(index + col, max(length - 1, 0))
    }
}
