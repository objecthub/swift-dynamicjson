//
//  DynamicJSONTests.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 11.02.2024.
//

import XCTest
@testable import DynamicJSON

class DynamicJSONTests: XCTestCase {

  func testKeyPath() {
    let json: JSON = [
        "string": "one two",
        "boolean": true,
        "number": 123,
        "object": [
            "str": "col",
            "arr": [1, 2, 3],
            "obj": [
                "x": "rah",
                "y": "tar",
                "z": ["zero", "one", "two"]
            ]
        ]
    ]
    XCTAssertEqual(try json[keyPath: "string"], "one two")
    XCTAssertEqual(try json[keyPath: "boolean"], true)
    XCTAssertEqual(try json[keyPath: "number"], 123)
    XCTAssertEqual(try json[keyPath: "object.str"], "col")
    XCTAssertEqual(try json[keyPath: "object.arr"], [1, 2, 3])
    XCTAssertEqual(try json[keyPath: "object.obj.y"], "tar")
    XCTAssertEqual(try json[keyPath: "object.obj.z[1]"], "one")
  }
  
  func testKeyPath2() throws {
    let json = try JSON(encoded: """
          {
            "string2": "foo bar",
            "boolean": true,
            "number": 123,
            "float": 17.5,
            "object": {
              "str": "col",
              "arr": [1, 2, 3],
              "obj": {
                "x": "rah",
                "y": "tar",
                "z": ["zero", "one", "two"]
              }
            }
         }
        """)
    XCTAssertEqual(json[keyPath: \.string2], "foo bar")
    XCTAssertEqual(json[keyPath: \.boolean], true)
    XCTAssertEqual(json[keyPath: \.number], 123)
    XCTAssertEqual(json[keyPath: \.float], 17.5)
    XCTAssertEqual(json[keyPath: \.object?.str], "col")
    XCTAssertEqual(json[keyPath: \.object?.arr], [1, 2, 3])
    XCTAssertEqual(json[keyPath: \.object?.obj?.y], "tar")
    XCTAssertEqual(json[keyPath: \.object?.obj?.z?[1]], "one")
  }
}
