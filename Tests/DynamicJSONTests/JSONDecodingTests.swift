//
//  JSONDecodingTests.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 25/10/2026.
//

import XCTest
import DynamicJSON

final class JSONDecodingTests: XCTestCase {

  func testDecodingOfAllTypes() throws {
    let decoder = JSONDecoder()
    func decode(_ str: String) throws -> JSON {
      return try decoder.decode(JSON.self, from: Data(str.utf8))
    }
    XCTAssertEqual(try decode("null"), .null)
    XCTAssertEqual(try decode("true"), .boolean(true))
    XCTAssertEqual(try decode("42"), .integer(42))
    XCTAssertEqual(try decode("-2.5"), .float(-2.5))
    XCTAssertEqual(try decode("\"text\""), .string("text"))
    XCTAssertEqual(try decode("[]"), .array([]))
    XCTAssertEqual(try decode("{}"), .object([:]))
    XCTAssertEqual(try decode("[1, \"a\", false]"), .array([.integer(1), .string("a"), .boolean(false)]))
    XCTAssertEqual(try decode("{\"a\": 1}"), .object(["a": .integer(1)]))
  }

  func testDecodingOfNullValues() throws {
    let json = try JSON(string: #"""
      { "a": null,
        "b": [null, 1, null],
        "c": { "d": null, "e": [null, { "f": null }] },
        "g": [[null], []] }
    """#)
    let expected: JSON = [
      "a": nil,
      "b": [nil, 1, nil],
      "c": ["d": nil, "e": [nil, ["f": nil]]],
      "g": [[nil], []]
    ]
    XCTAssertEqual(json, expected)
    XCTAssertEqual(json["a"], .null)
    XCTAssertEqual(json["b"]?[0], .null)
    XCTAssertEqual(json["b"]?[1], .integer(1))
    XCTAssertEqual(json["c"]?["e"]?[1]?["f"], .null)
  }

  func testCodableRoundtrip() throws {
    let json: JSON = [
      "null": nil,
      "bool": true,
      "int": 12,
      "float": 1.5,
      "string": "text",
      "array": [nil, true, 3, 2.5, "x", [nil], [:]],
      "object": ["a": nil, "b": ["c": [nil, nil]]]
    ]
    let data = try JSONEncoder().encode(json)
    XCTAssertEqual(try JSONDecoder().decode(JSON.self, from: data), json)
  }

  func testDecodingOfDecodableTypesWithJSONMembers() throws {
    struct Wrapper: Codable, Equatable {
      let id: Int
      let payload: JSON
      let extras: [JSON]
    }
    let text = #"{"id": 7, "payload": {"a": [null, 1]}, "extras": [null, {"b": null}]}"#
    let wrapper = try JSONDecoder().decode(Wrapper.self, from: Data(text.utf8))
    XCTAssertEqual(wrapper.id, 7)
    XCTAssertEqual(wrapper.payload, ["a": [nil, 1]])
    XCTAssertEqual(wrapper.extras, [nil, ["b": nil]])
  }
}
