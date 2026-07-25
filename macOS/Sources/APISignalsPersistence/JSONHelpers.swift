import Foundation
import GRDB
import APISignalsCore

enum PersistenceError: Error {
    case encodingFailed
    case decodingFailed
    case notFound
}

extension PersistenceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode entity"
        case .decodingFailed:
            return "Failed to decode entity"
        case .notFound:
            return "Entity not found"
        }
    }
}

final class JSON {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw PersistenceError.encodingFailed
        }
        return string
    }

    static func decode<T: Decodable>(_ string: String?, as type: T.Type) throws -> T {
        guard let string = string, !string.isEmpty else {
            throw PersistenceError.decodingFailed
        }
        let data = Data(string.utf8)
        return try decoder.decode(type, from: data)
    }

    static func decode<T: Decodable>(_ string: String?, as type: T.Type, default defaultValue: T) -> T {
        do {
            return try decode(string, as: type)
        } catch {
            return defaultValue
        }
    }
}
