//
//  JSONConstructorTests.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 12.02.2024.
//

import XCTest
@testable import DynamicJSON

final class JSONConstructorTests: XCTestCase {
  
  struct Person: Codable {
    let name: String
    let age: Int
    let children: [Person]
  }

  func testLiteralInit() {
    XCTAssertEqual(nil as JSON, .null)
    XCTAssertEqual(true as JSON, .boolean(true))
    XCTAssertEqual([1, 2] as JSON, .array([.integer(1), .integer(2)]))
    XCTAssertEqual(["x" : 1] as JSON, .object(["x": .integer(1)]))
    XCTAssertEqual(3.4028236e+38 as JSON, .float(3.4028236e+38))
    XCTAssertEqual("foo" as JSON, .string("foo"))
  }
  
  func testCodableInit() {
    let children = [Person(name: "Michael Doe", age: 5, children: []),
                    Person(name: "Linda Doe", age: 9, children: [])]
    let person = Person(name: "John Doe", age: 39, children: children)
    let json: JSON = .object([
      "name": "John Doe",
      "age": 39,
      "children": [.object(["name": "Michael Doe", "age": 5, "children": []]),
                   .object(["name": "Linda Doe", "age": 9, "children": []])]])
    XCTAssertEqual(person.jsonValue, json)
  }
  
  func testExample() throws {
    
  }

}
