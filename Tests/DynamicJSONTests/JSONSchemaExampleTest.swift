//
//  JSONSchemaExampleTest.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 19/04/2024.
//

import XCTest
@testable import DynamicJSON

final class JSONSchemaExampleTest: XCTestCase {
  func testExample() throws {
    let schema = try JSONSchema(string: #"""
      {
        "$id": "https://objecthub.com/example/person",
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "person",
        "type": "object",
        "properties": {
          "name": {
            "type": "string",
            "minLength": 1
          },
          "birthday": {
            "type": "string",
            "format": "date"
          },
          "numChildren": {
            "type": "integer",
            "default": 0
          },
          "address": {
            "oneOf": [
              { "type": "string", "default": "12345 Mcity" },
              { "$ref": "#address",
                "default": { "city": "Mcity", "postalCode": "12345" } }
            ]
          },
          "email": {
            "type": "array",
            "maxItems": 3,
            "items": {
              "type": "string",
              "format": "email"
            }
          }
        },
        "required": ["name", "birthday"],
        "$defs": {
          "address": {
            "$anchor": "address",
            "type": "object",
            "properties": {
              "street": {
                "type": "string"
              },
              "city": {
                "type": "string"
              },
              "postalCode": {
                "type": "string",
                "pattern": "\\d{5}"
              }
            },
            "required": ["city", "postalCode"]
          }
        }
      }
    """#)
    XCTAssertEqual(schema.id, JSONSchemaIdentifier(string: "https://objecthub.com/example/person"))
    let instance0: JSON = [
      "name": "John Doe",
      "birthday": "1983-03-19",
      "numChildren": 2,
      "email": ["john@doe.com", "john.doe@gmail.com"]
    ]
    XCTAssert(instance0.valid(for: schema))
    let instance1: JSON = [
      "name": "John Doe",
      "email": ["john@doe.com", "john.doe@gmail.com"]
    ]
    XCTAssertFalse(instance1.valid(for: schema))
    let instance2: JSON = [
      "name": "John Doe",
      "birthday": "1983-03-19",
      "address": "12 Main Street, 17445 Noname"
    ]
    let res2 = try instance2.validate(with: schema)
    XCTAssert(res2.isValid)
    XCTAssertEqual(res2.defaults.count, 2)
    XCTAssert(res2.defaults[try JSONLocation("$.numChildren")] != nil)
    XCTAssert(res2.defaults[try JSONLocation("$.address")] != nil)
    XCTAssertEqual(res2.defaults[try JSONLocation("$.numChildren")]?.values.count, 1)
    XCTAssertEqual(res2.defaults[try JSONLocation("$.address")]?.values.count, 2)
    XCTAssertEqual(res2.nonexistingDefaults.count, 1)
    let instance20 = try instance2.applying(patch: res2.defaultPatch)
    let res20 = try instance20.validate(with: schema)
    XCTAssert(res20.isValid)
    XCTAssertEqual(res20.nonexistingDefaults.count, 0)
    let instance3: JSON = [
      "name": "John Doe",
      "birthday": "1983-03-19",
      "address": [
        "street": "Main Street 12",
        "city": "Noname",
        "postalCode": "17445"
      ]
    ]
    XCTAssert(instance3.valid(for: schema))
    let instance4: JSON = [
      "name": "John Doe",
      "birthday": "1983-03-19",
      "address": 17445
    ]
    XCTAssertFalse(instance4.valid(for: schema))
    let instance5: JSON = [
      "name": "John Doe",
      "birthday": "1983-03-19",
      "address": [
        "street": "Main Street 12",
        "city": "Noname"
      ]
    ]
    XCTAssertFalse(instance5.valid(for: schema))
    let instance6: JSON = [
      "name": "John Doe",
      "birthday": "1983-03-19",
      "address": "john's address",
      "email": ["john", "doe", "john.doe@gmail.com"]
    ]
    let result = try instance6.validate(with: schema)
    XCTAssert(result.isValid)
    XCTAssertEqual(result.formatConstraints.count, 4)
    XCTAssertFalse(instance6.valid(for: schema, dialect: .draft2020Format))
    let instance7: JSON = [
      "name": "John Doe",
      "birthday": "1983-03-19",
      "email": ["john@doe.com", "jd@jdoe.com", "j.doe@gmail.com", "foo@bar.com"]
    ]
    XCTAssertFalse(instance7.valid(for: schema))
  }
}
