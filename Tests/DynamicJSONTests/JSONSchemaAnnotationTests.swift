//
//  JSONSchemaAnnotationTests.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 25/10/2026.
//

import XCTest
@testable import DynamicJSON

final class JSONSchemaAnnotationTests: XCTestCase {

  func testTagsOfRootSchema() throws {
    let schema = try JSONSchema(string: #"{"deprecated": true}"#)
    let result = try JSON.integer(1).validate(with: schema)
    XCTAssert(result.isValid)
    XCTAssertEqual(result.tags.count, 1)
    XCTAssertEqual(result.tags.first?.message, .deprecated)
  }

  func testTagsOfNestedSchemas() throws {
    let schema = try JSONSchema(string: #"""
      {
        "type": "object",
        "properties": {
          "old": { "type": "string", "deprecated": true },
          "id": { "type": "integer", "readOnly": true },
          "secret": { "type": "string", "writeOnly": true, "default": "none" },
          "list": {
            "type": "array",
            "items": { "type": "integer", "deprecated": true }
          },
          "plain": { "type": "string" }
        }
      }
    """#)
    let instance: JSON = [
      "old": "x",
      "id": 1,
      "secret": "s",
      "list": [1, 2],
      "plain": "p"
    ]
    let result = try instance.validate(with: schema)
    XCTAssert(result.isValid)
    var tagged: [String : JSONSchemaValidationResult.MetaTags] = [:]
    for tag in result.tags {
      tagged[tag.value.location.description] = tag.message
    }
    XCTAssertEqual(result.tags.count, 5)
    XCTAssertEqual(tagged["$['old']"], .deprecated)
    XCTAssertEqual(tagged["$['id']"], .readOnly)
    XCTAssertEqual(tagged["$['secret']"], .writeOnly)
    XCTAssertEqual(tagged["$['list'][0]"], .deprecated)
    XCTAssertEqual(tagged["$['list'][1]"], .deprecated)
    XCTAssertNil(tagged["$['plain']"])
  }

  func testTagsOfCombinedSchemas() throws {
    let schema = try JSONSchema(string: #"""
      {
        "allOf": [
          { "properties": { "a": { "deprecated": true } } },
          { "properties": { "b": { "readOnly": true } } }
        ],
        "anyOf": [
          { "properties": { "c": { "writeOnly": true } } },
          { "type": "string" }
        ]
      }
    """#)
    let instance: JSON = ["a": 1, "b": 2, "c": 3]
    let result = try instance.validate(with: schema)
    XCTAssert(result.isValid)
    XCTAssertEqual(result.tags.count, 3)
    // Tags of schemas that fail are not reported
    let failing = try JSONSchema(string: #"""
      { "oneOf": [ { "properties": { "a": { "deprecated": true } }, "required": ["z"] },
                   { "properties": { "a": { "readOnly": true } } } ] }
    """#)
    let result2 = try instance.validate(with: failing)
    XCTAssert(result2.isValid)
    XCTAssertEqual(result2.tags.count, 1)
    XCTAssertEqual(result2.tags.first?.message, .readOnly)
  }

  func testOneOfFailureIsReportedForOneOf() throws {
    let schema = try JSONSchema(string: #"""
      { "oneOf": [ { "type": "string" }, { "type": "integer" } ] }
    """#)
    let result = try JSON.boolean(true).validate(with: schema)
    XCTAssertFalse(result.isValid)
    XCTAssertEqual(result.errors.count, 1)
    XCTAssertEqual(result.errors.first?.location.description, "$['oneOf']")
  }

  func testAnyOfFailureIsReportedForAnyOf() throws {
    let schema = try JSONSchema(string: #"""
      { "anyOf": [ { "type": "string" }, { "type": "integer" } ] }
    """#)
    let result = try JSON.boolean(true).validate(with: schema)
    XCTAssertFalse(result.isValid)
    XCTAssertEqual(result.errors.count, 1)
    XCTAssertEqual(result.errors.first?.location.description, "$['anyOf']")
  }

  func testOneOfWithTooManyMatches() throws {
    let schema = try JSONSchema(string: #"""
      { "oneOf": [ { "type": "integer" }, { "minimum": 0 } ] }
    """#)
    let result = try JSON.integer(5).validate(with: schema)
    XCTAssertFalse(result.isValid)
    XCTAssertEqual(result.errors.count, 1)
    XCTAssertEqual(result.errors.first?.location.description, "$['oneOf']")
  }
}
