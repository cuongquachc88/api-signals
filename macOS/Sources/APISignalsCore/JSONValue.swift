import Foundation

public struct JSONObjectEntry: Equatable, Sendable {
    public var key: String
    public var value: JSONValue

    public init(key: String, value: JSONValue) {
        self.key = key
        self.value = value
    }
}

/// In-memory JSON value used by the tree editor.
public enum JSONValue: Equatable, Sendable {
    case object([JSONObjectEntry])
    case array([JSONValue])
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    public var isContainer: Bool {
        switch self {
        case .object, .array: return true
        default: return false
        }
    }

    public var childCount: Int {
        switch self {
        case .object(let entries): return entries.count
        case .array(let items): return items.count
        default: return 0
        }
    }

    public static func parse(from text: String) throws -> JSONValue {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .object([]) }
        guard let data = trimmed.data(using: .utf8) else {
            throw JSONFormatError.invalid("Invalid UTF-8")
        }
        let any: Any
        do {
            any = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw JSONFormatError.invalid((error as NSError).localizedDescription)
        }
        return fromAny(any)
    }

    public func serialize(pretty: Bool) throws -> String {
        let any = toAny()
        var options: JSONSerialization.WritingOptions = [.withoutEscapingSlashes]
        if pretty { options.insert([.prettyPrinted, .sortedKeys]) }
        let data: Data
        if JSONSerialization.isValidJSONObject(any) {
            data = try JSONSerialization.data(withJSONObject: any, options: options)
        } else {
            data = try encodeFragment(any)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw JSONFormatError.invalid("Could not encode JSON")
        }
        return text
    }

    private func encodeFragment(_ any: Any) throws -> Data {
        if let s = any as? String {
            return Data("\"\(s.jsonEscaped())\"".utf8)
        }
        if any is NSNull {
            return Data("null".utf8)
        }
        if let n = any as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                return Data((n.boolValue ? "true" : "false").utf8)
            }
            return Data(n.stringValue.utf8)
        }
        throw JSONFormatError.invalid("Unsupported JSON fragment")
    }

    private static func fromAny(_ any: Any) -> JSONValue {
        switch any {
        case let dict as [String: Any]:
            let entries = dict.keys.sorted().map { JSONObjectEntry(key: $0, value: fromAny(dict[$0]!)) }
            return .object(entries)
        case let arr as [Any]:
            return .array(arr.map(fromAny))
        case let s as String:
            return .string(s)
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                return .bool(n.boolValue)
            }
            return .number(n.stringValue)
        case is NSNull:
            return .null
        default:
            return .string(String(describing: any))
        }
    }

    private func toAny() -> Any {
        switch self {
        case .object(let entries):
            var dict: [String: Any] = [:]
            for entry in entries { dict[entry.key] = entry.value.toAny() }
            return dict
        case .array(let items):
            return items.map { $0.toAny() }
        case .string(let s):
            return s
        case .number(let n):
            if let i = Int(n) { return i }
            if let d = Double(n) { return d }
            return n
        case .bool(let b):
            return b
        case .null:
            return NSNull()
        }
    }
}

private extension String {
    func jsonEscaped() -> String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
