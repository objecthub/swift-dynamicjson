//
//  DynamicJSONTests.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 11/02/2024.
//  Copyright © 2024 Matthias Zenger. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import XCTest
@testable import DynamicJSON

class DynamicJSONTests: XCTestCase {

  struct Person: Codable {
    let name: String
    let age: Int
    let children: [Person]
  }
  
  func testConversion() throws {
    let person = Person(name: "John", age: 34, children: [Person(name: "Sofia", age: 5, children: [])])
    let json2 = try JSON(encodable: person)
    let json3 = try JSON(string: """
      {
        "age" : 34,
        "children" : [
          {
            "age" : 5,
            "children" : [],
            "name" : "Sofia"
          }
        ],
        "name" : "John"
      }
    """)
    XCTAssertEqual(json2, json3)
  }
  
  func testInitializers() throws {
    let json0: JSON = [
      "foo": true,
      "bar": 123,
      "str": "one two",
      "object": [
        "value": nil,
        "arr": [1, 2, 3],
        "obj": [ "x" : 17.6 ]
      ]
    ]
    let json1 = try JSON(string: """
      {
        "foo": true,
        "bar": 123,
        "str": "one two",
        "object": {
          "value": null,
          "arr": [1, 2, 3],
          "obj": { "x" : 17.6 }
        }
      }
    """)
    XCTAssertEqual(json0, json1)
    XCTAssertEqual(json1.object?.arr?[0], 1)
    XCTAssertEqual(json1[keyPath: \.object?.arr?[0]], 1)
    XCTAssertEqual(json1["object"]?["arr"]?[0], 1)
    XCTAssertEqual(try json1[ref: "/object/arr/0"], 1)
    XCTAssertEqual(try json1[ref: "$.object.arr[0]"], 1)
  }
  
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
    XCTAssertEqual(try json[ref: "string"], "one two")
    XCTAssertEqual(try json[ref: "boolean"], true)
    XCTAssertEqual(try json[ref: "number"], 123)
    XCTAssertEqual(try json[ref: "object.str"], "col")
    XCTAssertEqual(try json[ref: "object.arr"], [1, 2, 3])
    XCTAssertEqual(try json[ref: "object.obj.y"], "tar")
    XCTAssertEqual(try json[ref: "object.obj.z[1]"], "one")
  }
  
  func testKeyPath2() throws {
    let json = try JSON(string: """
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
