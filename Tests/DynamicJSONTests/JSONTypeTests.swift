//
//  JSONTypeTests.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 16/03/2024.
//

import XCTest
@testable import DynamicJSON

final class JSONTypeTests: XCTestCase {
  
  public func testBaseTypeDescription() {
    XCTAssertEqual(JSONType.null.description, "null")
    XCTAssertEqual(JSONType.boolean.description, "boolean")
    XCTAssertEqual(JSONType.number.description, "number")
    XCTAssertEqual(JSONType.integer.description, "integer")
    XCTAssertEqual(JSONType.string.description, "string")
    XCTAssertEqual(JSONType.array.description, "array")
    XCTAssertEqual(JSONType.object.description, "object")
  }
  
  public func testCompositeTypeDescription() {
    var type: JSONType = []
    XCTAssertEqual(type.description, "none")
    type  = [.number, .string]
    XCTAssertEqual(type.description, "number or string")
    type = .all
    XCTAssertEqual(type.description, "null, boolean, number, integer, string, array or object")
  }
}
