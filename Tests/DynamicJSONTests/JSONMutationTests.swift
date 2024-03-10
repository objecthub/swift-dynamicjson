//
//  JSONMutationTests.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 10/03/2024.
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

final class JSONMutationTests: XCTestCase {

  func testAppend() {
    var json: JSON = .array([1, 2, 3])
    XCTAssertNoThrow(try json.append(.integer(4)))
    XCTAssertEqual(json, .array([1, 2, 3, 4]))
    json = .array([])
    XCTAssertNoThrow(try json.append(.integer(-1)))
    XCTAssertEqual(json, .array([-1]))
    json = .string("Hello")
    XCTAssertNoThrow(try json.append(.string(" World")))
    XCTAssertEqual(json, .string("Hello World"))
    json = .integer(8)
    XCTAssertNil(try? json.append(.integer(4)))
  }
  
  func testAssign() {
    var json: JSON = .object(["foo" : .string("foo"), "bar" : .float(3.9)])
    XCTAssertNoThrow(try json.assign("baz", to: .array([.integer(17)])))
    XCTAssertEqual(json, .object(["foo" : .string("foo"),
                                  "bar" : .float(3.9),
                                  "baz" : .array([.integer(17)])]))
    json = .object(["foo" : .string("foo"), "bar" : .float(3.9)])
    XCTAssertNoThrow(try json.assign("bar", to: .array([.integer(17)])))
    XCTAssertEqual(json, .object(["foo" : .string("foo"),
                                  "bar" : .array([.integer(17)])]))
    json = .integer(8)
    XCTAssertNil(try? json.assign("four", to: .integer(4)))
  }
  
  func testMutation() {
    var json: JSON = [
        "string": "one two",
        "boolean": true,
        "number": 123,
        "object": [
            "str": "col",
            "arr": [1, 2, ["one" : 1, "two" : 2]],
            "obj": [
                "x": "rah",
                "y": "tar",
                "z": ["zero", "one", "two"]
            ]
        ]
    ]
    let result1: JSON = [
        "string": "one two",
        "boolean": true,
        "number": 123,
        "object": [
            "str": "col",
            "arr": [1, 2, ["one" : 1, "two" : 2]],
            "obj": [
                "x": "rah",
                "y": "tar",
                "z": ["one", "two", "three"]
            ]
        ]
    ]
    let result2: JSON = [
        "string": "one two",
        "boolean": true,
        "number": 123,
        "object": [
            "str": "col",
            "arr": [1, "two", ["one" : 1, "two" : 2]],
            "obj": [
                "x": "rah",
                "y": "tar",
                "z": ["one", "two", "three"]
            ]
        ]
    ]
    let result3: JSON = [
        "string": "one two",
        "boolean": true,
        "number": 123,
        "object": [
            "str": "col",
            "arr": [1, "two", ["one" : 1, "two" : 4, "three": 3]],
            "obj": [
                "x": "rah",
                "y": "tar",
                "z": ["one", "two", "three"]
            ]
        ]
    ]
    let result4: JSON = [
        "string": "one two",
        "boolean": false,
        "number": 123,
        "object": [
            "str": "col",
            "arr": [1, "two", ["one" : 1, "two" : 4, "three": 3]],
            "obj": [
                "x": "rah",
                "y": "tar",
                "z": ["one", "two", "threeappended"]
            ]
        ]
    ]
    XCTAssertNoThrow(try json.mutate(array: "$.object.obj.z") { arr in
      arr.removeFirst()
      arr.append("three")
    })
    XCTAssertEqual(json, result1)
    XCTAssertNoThrow(try json.update("$.object.arr[1]", with: "two"))
    XCTAssertEqual(json, result2)
    XCTAssertNoThrow(try json.mutate("$.object.arr[2].two") { value in
      guard case .integer(let x) = value else {
        throw JSON.Error.typeMismatch(.number, value)
      }
      value = .integer(2 * x)
    })
    XCTAssertNoThrow(try json.mutate(object: "/object/arr/2") { dict in
      dict["three"] = 3
    })
    XCTAssertEqual(json, result3)
    XCTAssertNoThrow(try json.mutate("$.boolean") { $0 = .boolean(false) })
    XCTAssertNoThrow(try json.mutate("/object/obj/z/2") { value in
      try value.append("appended")
    })
    XCTAssertEqual(json, result4)
  }
}
