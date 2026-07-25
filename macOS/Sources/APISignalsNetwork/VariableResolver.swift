import Foundation
import APISignalsCore

public struct DefaultVariableResolver: VariableResolver, Sendable {
    public init() {}

    public func resolve(_ string: String, context: VariableResolutionContext) -> String {
        var result = string
        let allVariables = orderedVariables(from: context)

        // Match {{variableName}} or {{variableName:defaultValue}}
        let pattern = #"\{\{\s*([a-zA-Z0-9_\-]+)\s*(?::\s*([^}]*)\s*)?\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return result
        }

        let range = NSRange(result.startIndex..., in: result)
        let matches = regex.matches(in: result, options: [], range: range)

        // Replace from end to start to preserve ranges
        for match in matches.reversed() {
            let fullRange = Range(match.range, in: result)!
            let nameRange = Range(match.range(at: 1), in: result)!
            let name = String(result[nameRange])
            let defaultValue: String? = {
                if match.range(at: 2).location != NSNotFound,
                   let range = Range(match.range(at: 2), in: result) {
                    let value = String(result[range]).trimmingCharacters(in: .whitespaces)
                    return value.isEmpty ? nil : value
                }
                return nil
            }()

            let resolved = allVariables[name] ?? defaultValue ?? String(result[fullRange])
            result.replaceSubrange(fullRange, with: resolved)
        }

        return result
    }

    private func orderedVariables(from context: VariableResolutionContext) -> [String: String] {
        var result: [String: String] = [:]

        let sources: [[Variable]] = [
            context.globalVariables,
            context.environmentVariables,
            context.collectionVariables,
            context.requestVariables
        ]

        for source in sources {
            for variable in source where variable.isEnabled {
                result[variable.key] = variable.value
            }
        }

        return result
    }
}
