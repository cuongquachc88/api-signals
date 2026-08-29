import XCTest
import APISignalsCore

final class GraphQLSchemaTests: XCTestCase {

    // MARK: - Introspection parsing

    func testParseMinimalSchema() throws {
        let json = """
        {
          "data": {
            "__schema": {
              "queryType": { "name": "Query" },
              "mutationType": null,
              "subscriptionType": null,
              "types": [
                {
                  "kind": "OBJECT",
                  "name": "Query",
                  "description": null,
                  "fields": [
                    {
                      "name": "user",
                      "description": "Fetch a user",
                      "args": [],
                      "type": { "kind": "OBJECT", "name": "User", "ofType": null }
                    }
                  ],
                  "inputFields": [],
                  "enumValues": []
                },
                {
                  "kind": "OBJECT",
                  "name": "User",
                  "description": null,
                  "fields": [
                    {
                      "name": "id",
                      "description": null,
                      "args": [],
                      "type": { "kind": "SCALAR", "name": "ID", "ofType": null }
                    },
                    {
                      "name": "name",
                      "description": null,
                      "args": [],
                      "type": { "kind": "SCALAR", "name": "String", "ofType": null }
                    }
                  ],
                  "inputFields": [],
                  "enumValues": []
                }
              ]
            }
          }
        }
        """
        let data = Data(json.utf8)
        let schema = try GraphQLIntrospection.parse(data)

        XCTAssertEqual(schema.queryTypeName, "Query")
        XCTAssertNil(schema.mutationTypeName)
        XCTAssertNil(schema.subscriptionTypeName)
        XCTAssertEqual(schema.types.count, 2)

        let queryType = try XCTUnwrap(schema.rootQueryType)
        XCTAssertEqual(queryType.name, "Query")
        XCTAssertEqual(queryType.fields.count, 1)
        XCTAssertEqual(queryType.fields[0].name, "user")
        XCTAssertEqual(queryType.fields[0].description, "Fetch a user")
        XCTAssertEqual(queryType.fields[0].typeName, "User")

        let userType = try XCTUnwrap(schema.type(named: "User"))
        XCTAssertEqual(userType.fields.count, 2)
        XCTAssertEqual(userType.fields.map(\.name), ["id", "name"])
    }

    func testParseSchemaWithMutationAndSubscription() throws {
        let json = """
        {
          "data": {
            "__schema": {
              "queryType": { "name": "Query" },
              "mutationType": { "name": "Mutation" },
              "subscriptionType": { "name": "Subscription" },
              "types": []
            }
          }
        }
        """
        let schema = try GraphQLIntrospection.parse(Data(json.utf8))
        XCTAssertEqual(schema.mutationTypeName, "Mutation")
        XCTAssertEqual(schema.subscriptionTypeName, "Subscription")
    }

    func testParseSchemaWithArguments() throws {
        let json = """
        {
          "data": {
            "__schema": {
              "queryType": { "name": "Query" },
              "mutationType": null,
              "subscriptionType": null,
              "types": [
                {
                  "kind": "OBJECT",
                  "name": "Query",
                  "description": null,
                  "fields": [
                    {
                      "name": "user",
                      "description": null,
                      "args": [
                        {
                          "name": "id",
                          "description": "User ID",
                          "type": { "kind": "SCALAR", "name": "ID", "ofType": null }
                        }
                      ],
                      "type": { "kind": "OBJECT", "name": "User", "ofType": null }
                    }
                  ],
                  "inputFields": [],
                  "enumValues": []
                }
              ]
            }
          }
        }
        """
        let schema = try GraphQLIntrospection.parse(Data(json.utf8))
        let field = try XCTUnwrap(schema.rootQueryType?.fields.first)
        XCTAssertEqual(field.args.count, 1)
        XCTAssertEqual(field.args[0].name, "id")
        XCTAssertEqual(field.args[0].typeName, "ID")
        XCTAssertEqual(field.args[0].description, "User ID")
    }

    func testParseSchemaWithEnumValues() throws {
        let json = """
        {
          "data": {
            "__schema": {
              "queryType": null,
              "mutationType": null,
              "subscriptionType": null,
              "types": [
                {
                  "kind": "ENUM",
                  "name": "Episode",
                  "description": null,
                  "fields": [],
                  "inputFields": [],
                  "enumValues": [
                    { "name": "NEWHOPE" },
                    { "name": "EMPIRE" },
                    { "name": "JEDI" }
                  ]
                }
              ]
            }
          }
        }
        """
        let schema = try GraphQLIntrospection.parse(Data(json.utf8))
        let episode = try XCTUnwrap(schema.type(named: "Episode"))
        XCTAssertEqual(episode.enumValues, ["NEWHOPE", "EMPIRE", "JEDI"])
    }

    func testParseSchemaWithInputType() throws {
        let json = """
        {
          "data": {
            "__schema": {
              "queryType": null,
              "mutationType": null,
              "subscriptionType": null,
              "types": [
                {
                  "kind": "INPUT_OBJECT",
                  "name": "CreateUserInput",
                  "description": null,
                  "fields": [],
                  "inputFields": [
                    {
                      "name": "name",
                      "description": null,
                      "type": { "kind": "SCALAR", "name": "String", "ofType": null }
                    },
                    {
                      "name": "email",
                      "description": null,
                      "type": { "kind": "SCALAR", "name": "String", "ofType": null }
                    }
                  ],
                  "enumValues": []
                }
              ]
            }
          }
        }
        """
        let schema = try GraphQLIntrospection.parse(Data(json.utf8))
        let input = try XCTUnwrap(schema.type(named: "CreateUserInput"))
        XCTAssertEqual(input.inputFields.count, 2)
        XCTAssertEqual(input.inputFields.map(\.name), ["name", "email"])
    }

    func testParseSchemaFlattenNestedTypeRef() throws {
        // NON_NULL wrapping a LIST wrapping a named type
        let json = """
        {
          "data": {
            "__schema": {
              "queryType": { "name": "Query" },
              "mutationType": null,
              "subscriptionType": null,
              "types": [
                {
                  "kind": "OBJECT",
                  "name": "Query",
                  "description": null,
                  "fields": [
                    {
                      "name": "users",
                      "description": null,
                      "args": [],
                      "type": {
                        "kind": "NON_NULL",
                        "name": null,
                        "ofType": {
                          "kind": "LIST",
                          "name": null,
                          "ofType": {
                            "kind": "OBJECT",
                            "name": "User",
                            "ofType": null
                          }
                        }
                      }
                    }
                  ],
                  "inputFields": [],
                  "enumValues": []
                }
              ]
            }
          }
        }
        """
        let schema = try GraphQLIntrospection.parse(Data(json.utf8))
        let field = try XCTUnwrap(schema.rootQueryType?.fields.first)
        // Should unwrap through NON_NULL → LIST → User
        XCTAssertEqual(field.typeName, "User")
    }

    func testParseSchemaErrorResponse() {
        let json = """
        {
          "errors": [{ "message": "Introspection disabled" }]
        }
        """
        XCTAssertThrowsError(try GraphQLIntrospection.parse(Data(json.utf8))) { error in
            guard case GraphQLSchemaError.fetchFailed(let msg) = error else {
                return XCTFail("Expected fetchFailed, got \(error)")
            }
            XCTAssertEqual(msg, "Introspection disabled")
        }
    }

    func testParseSchemaInvalidFormat() {
        let json = #"{ "data": { "other": {} } }"#
        XCTAssertThrowsError(try GraphQLIntrospection.parse(Data(json.utf8))) { error in
            guard case GraphQLSchemaError.fetchFailed = error else {
                return XCTFail("Expected fetchFailed")
            }
        }
    }

    // MARK: - GraphQLSchema helpers

    func testBuiltinTypeFilter() throws {
        let json = """
        {
          "data": {
            "__schema": {
              "queryType": { "name": "Query" },
              "mutationType": null,
              "subscriptionType": null,
              "types": [
                { "kind": "OBJECT", "name": "Query", "description": null, "fields": [], "inputFields": [], "enumValues": [] },
                { "kind": "OBJECT", "name": "__Schema", "description": null, "fields": [], "inputFields": [], "enumValues": [] },
                { "kind": "SCALAR", "name": "__Type", "description": null, "fields": [], "inputFields": [], "enumValues": [] }
              ]
            }
          }
        }
        """
        let schema = try GraphQLIntrospection.parse(Data(json.utf8))
        XCTAssertEqual(schema.types.count, 3)
        XCTAssertEqual(schema.userTypes.count, 1)
        XCTAssertEqual(schema.userTypes[0].name, "Query")
    }

    func testTypeLookupByName() throws {
        let json = """
        {
          "data": {
            "__schema": {
              "queryType": null, "mutationType": null, "subscriptionType": null,
              "types": [
                { "kind": "OBJECT", "name": "Foo", "description": null, "fields": [], "inputFields": [], "enumValues": [] }
              ]
            }
          }
        }
        """
        let schema = try GraphQLIntrospection.parse(Data(json.utf8))
        XCTAssertNotNil(schema.type(named: "Foo"))
        XCTAssertNil(schema.type(named: "Bar"))
    }

    // MARK: - Introspection query string

    func testIntrospectionQueryIsNonEmpty() {
        XCTAssertFalse(GraphQLIntrospection.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue(GraphQLIntrospection.query.contains("__schema"))
        XCTAssertTrue(GraphQLIntrospection.query.contains("queryType"))
        XCTAssertTrue(GraphQLIntrospection.query.contains("fields"))
    }
}
