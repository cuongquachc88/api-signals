import Foundation
import JavaScriptCore
import APISignalsCore

public struct ScriptResult: Sendable {
    public var environmentVariables: [String: String]
    public var globalVariables: [String: String]
    public var collectionVariables: [String: String]
    public var tests: [ScriptTest]
    public var errors: [String]

    public init(
        environmentVariables: [String: String] = [:],
        globalVariables: [String: String] = [:],
        collectionVariables: [String: String] = [:],
        tests: [ScriptTest] = [],
        errors: [String] = []
    ) {
        self.environmentVariables = environmentVariables
        self.globalVariables = globalVariables
        self.collectionVariables = collectionVariables
        self.tests = tests
        self.errors = errors
    }
}

public struct ScriptTest: Sendable, Identifiable {
    public let id = UUID()
    public var name: String
    public var passed: Bool
    public var message: String?

    public init(name: String, passed: Bool, message: String? = nil) {
        self.name = name
        self.passed = passed
        self.message = message
    }
}

private final class MutableVariableStore {
    var environment: [String: String]
    var collection: [String: String]
    var globals: [String: String]

    init(environment: [String: String], collection: [String: String], globals: [String: String]) {
        self.environment = environment
        self.collection = collection
        self.globals = globals
    }
}

@MainActor
public final class JavaScriptCoreRunner {
    public init() {}

    public func runPreRequest(
        script: String,
        request: APIRequest,
        environment: APISignalsCore.Environment?,
        collectionVariables: [Variable] = [],
        globalVariables: [Variable] = []
    ) async -> ScriptResult {
        let initialValues = variableDictionaries(
            environment: environment,
            collectionVariables: collectionVariables,
            globalVariables: globalVariables
        )

        return await runScript(
            script: script,
            request: request,
            response: nil,
            initialValues: initialValues
        )
    }

    public func runPostResponse(
        script: String,
        request: APIRequest,
        response: APIResponse,
        environment: APISignalsCore.Environment?,
        collectionVariables: [Variable] = [],
        globalVariables: [Variable] = []
    ) async -> ScriptResult {
        let initialValues = variableDictionaries(
            environment: environment,
            collectionVariables: collectionVariables,
            globalVariables: globalVariables
        )

        return await runScript(
            script: script,
            request: request,
            response: response,
            initialValues: initialValues
        )
    }

    private func variableDictionaries(
        environment: APISignalsCore.Environment?,
        collectionVariables: [Variable],
        globalVariables: [Variable]
    ) -> (environment: [String: String], collection: [String: String], globals: [String: String]) {
        let envDict = (environment?.variables ?? [])
            .filter { $0.isEnabled }
            .reduce(into: [:]) { $0[$1.key] = $1.value }
        let collectionDict = collectionVariables
            .filter { $0.isEnabled }
            .reduce(into: [:]) { $0[$1.key] = $1.value }
        let globalsDict = globalVariables
            .filter { $0.isEnabled }
            .reduce(into: [:]) { $0[$1.key] = $1.value }
        return (envDict, collectionDict, globalsDict)
    }

    private func runScript(
        script: String,
        request: APIRequest,
        response: APIResponse?,
        initialValues: (environment: [String: String], collection: [String: String], globals: [String: String])
    ) async -> ScriptResult {
        guard !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ScriptResult()
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: ScriptResult(errors: ["Runner deallocated"]))
                    return
                }
                let result = self.executeScript(script, request: request, response: response, initialValues: initialValues)
                continuation.resume(returning: result)
            }
        }
    }

    private func executeScript(
        _ script: String,
        request: APIRequest,
        response: APIResponse?,
        initialValues: (environment: [String: String], collection: [String: String], globals: [String: String])
    ) -> ScriptResult {
        let context = JSContext()!
        let store = MutableVariableStore(
            environment: initialValues.environment,
            collection: initialValues.collection,
            globals: initialValues.globals
        )

        var tests: [ScriptTest] = []
        var errors: [String] = []

        context.exceptionHandler = { _, exception in
            if let exception = exception {
                errors.append(exception.toString())
            }
        }

        // pm object
        let pm = JSValue(object: [:], in: context)!

        // pm.environment
        pm.setValue(createStore(context: context, store: store, keyPath: \.environment), forProperty: "environment")

        // pm.collectionVariables
        pm.setValue(createStore(context: context, store: store, keyPath: \.collection), forProperty: "collectionVariables")

        // pm.globals
        pm.setValue(createStore(context: context, store: store, keyPath: \.globals), forProperty: "globals")

        // pm.variables
        pm.setValue(createVariableStore(context: context, store: store), forProperty: "variables")

        // pm.request
        pm.setValue(createRequestObject(context: context, request: request), forProperty: "request")

        // pm.response
        if let response = response {
            pm.setValue(createResponseObject(context: context, response: response), forProperty: "response")
        }

        // pm.test
        let testFunction: @convention(block) (String, JSValue) -> Void = { name, fn in
            let testResult: ScriptTest
            if fn.isObject {
                let function = fn
                let result = function.call(withArguments: [])
                if let exception = context.exception, !exception.isUndefined {
                    testResult = ScriptTest(name: name, passed: false, message: exception.toString())
                    context.exception = nil
                } else if result?.isBoolean == true, result?.toBool() == false {
                    testResult = ScriptTest(name: name, passed: false, message: "Assertion failed")
                } else {
                    testResult = ScriptTest(name: name, passed: true)
                }
            } else {
                testResult = ScriptTest(name: name, passed: false, message: "Test function required")
            }
            tests.append(testResult)
        }
        pm.setValue(testFunction, forProperty: "test")

        // pm.expect
        let expectFunction: @convention(block) (JSValue) -> JSValue = { [weak self] value in
            guard let self = self else { return JSValue(object: [:], in: context)! }
            return self.createExpectation(context: context, value: value)
        }
        pm.setValue(expectFunction, forProperty: "expect")

        context.setObject(pm, forKeyedSubscript: "pm" as NSString)

        // console.log
        let console = JSValue(object: [:], in: context)!
        let logFunction: @convention(block) (String) -> Void = { message in
            print("[JS] \(message)")
        }
        console.setValue(logFunction, forProperty: "log")
        context.setObject(console, forKeyedSubscript: "console" as NSString)

        // Execute script
        context.evaluateScript(script)
        if let exception = context.exception, !exception.isUndefined {
            errors.append(exception.toString())
            context.exception = nil
        }

        return ScriptResult(
            environmentVariables: store.environment,
            globalVariables: store.globals,
            collectionVariables: store.collection,
            tests: tests,
            errors: errors
        )
    }

    private func createStore(context: JSContext, store: MutableVariableStore, keyPath: ReferenceWritableKeyPath<MutableVariableStore, [String: String]>) -> JSValue {
        let storeValue = JSValue(object: [:], in: context)!

        let setFunction: @convention(block) (String, String) -> Void = { key, value in
            store[keyPath: keyPath][key] = value
        }
        storeValue.setValue(setFunction, forProperty: "set")

        let getFunction: @convention(block) (String) -> String? = { key in
            return store[keyPath: keyPath][key]
        }
        storeValue.setValue(getFunction, forProperty: "get")

        let hasFunction: @convention(block) (String) -> Bool = { key in
            return store[keyPath: keyPath][key] != nil
        }
        storeValue.setValue(hasFunction, forProperty: "has")

        let unsetFunction: @convention(block) (String) -> Void = { key in
            store[keyPath: keyPath].removeValue(forKey: key)
        }
        storeValue.setValue(unsetFunction, forProperty: "unset")

        return storeValue
    }

    private func createVariableStore(context: JSContext, store: MutableVariableStore) -> JSValue {
        let storeValue = JSValue(object: [:], in: context)!

        let setFunction: @convention(block) (String, String) -> Void = { key, value in
            // Prefer environment, then collection, then globals
            if store.environment[key] != nil {
                store.environment[key] = value
            } else if store.collection[key] != nil {
                store.collection[key] = value
            } else {
                store.globals[key] = value
            }
        }
        storeValue.setValue(setFunction, forProperty: "set")

        let getFunction: @convention(block) (String) -> String? = { key in
            return store.environment[key] ?? store.collection[key] ?? store.globals[key]
        }
        storeValue.setValue(getFunction, forProperty: "get")

        return storeValue
    }

    private func createRequestObject(context: JSContext, request: APIRequest) -> JSValue {
        let obj = JSValue(object: [:], in: context)!
        obj.setValue(request.url.url?.absoluteString ?? "", forProperty: "url")
        obj.setValue(request.method.rawValue, forProperty: "method")
        obj.setValue(request.headers.reduce(into: [:]) { $0[$1.key] = $1.value }, forProperty: "headers")
        obj.setValue(request.body.bodyText, forProperty: "body")
        return obj
    }

    private func createResponseObject(context: JSContext, response: APIResponse) -> JSValue {
        let obj = JSValue(object: [:], in: context)!
        obj.setValue(response.statusCode, forProperty: "code")
        obj.setValue(response.statusText, forProperty: "status")
        obj.setValue(response.headers.reduce(into: [:]) { $0[$1.key] = $1.value }, forProperty: "headers")

        let jsonFunction: @convention(block) () -> [String: Any]? = {
            guard let data = response.body else { return nil }
            return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        }
        obj.setValue(jsonFunction, forProperty: "json")

        let textFunction: @convention(block) () -> String? = {
            guard let data = response.body else { return nil }
            return String(data: data, encoding: .utf8)
        }
        obj.setValue(textFunction, forProperty: "text")

        return obj
    }

    private func createExpectation(context: JSContext, value: JSValue) -> JSValue {
        let obj = JSValue(object: [:], in: context)!

        let toEqual: @convention(block) (JSValue) -> Bool = { expected in
            return value.isEqual(to: expected)
        }
        obj.setValue(toEqual, forProperty: "toEqual")

        let toExist: @convention(block) () -> Bool = {
            return !value.isUndefined && !value.isNull
        }
        obj.setValue(toExist, forProperty: "toExist")

        let toBeTrue: @convention(block) () -> Bool = {
            return value.toBool()
        }
        obj.setValue(toBeTrue, forProperty: "toBeTrue")

        let toBeFalse: @convention(block) () -> Bool = {
            return !value.toBool()
        }
        obj.setValue(toBeFalse, forProperty: "toBeFalse")

        return obj
    }
}

private extension RequestBody {
    var bodyText: String? {
        switch self {
        case .none, .formData, .urlEncoded, .binary:
            return nil
        case .raw(let text, _):
            return text
        case .json(let text):
            return text
        case .graphql(let query, _):
            return query
        }
    }
}

private extension JSValue {
    func isEqual(to other: JSValue) -> Bool {
        if self.isNumber && other.isNumber {
            return self.toDouble() == other.toDouble()
        }
        if self.isString && other.isString {
            return self.toString() == other.toString()
        }
        if self.isBoolean && other.isBoolean {
            return self.toBool() == other.toBool()
        }
        if self.isNull && other.isNull {
            return true
        }
        if self.isUndefined && other.isUndefined {
            return true
        }
        return false
    }
}
