//
//  JSONConstructorTests.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 12/02/2024.
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

final class JSONConstructorTests: XCTestCase {
  
  struct Person: Codable, Equatable {
    let name: String
    let age: Int
    let children: [Person]
  }
  
  struct Test: Codable, Equatable {
    let num: Int?
    let obj: JSON?
    
    init(num: Int?, obj: JSON?) {
      self.num = num
      self.obj = obj
    }
    /*
    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      self.num = try values.decodeIfPresent(Int.self, forKey: .num)
      self.obj = try? values.decode(JSON.self, forKey: .obj)
    }
     */
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
    let person2 = Person(json)
    XCTAssertEqual(person, person2)
  }
  
  func testCoerce() throws {
    let json3: JSON = [
      "name": "Matthew",
      "age": 29,
      "children": []
    ]
    let person3: Person = try json3.coerce()
    XCTAssertEqual(Person(name: "Matthew", age: 29, children: []), person3)
  }
  
  func testOptCodableInit() throws {
    let test = Test(num: 1, obj: .null)
    let json = try JSON(test)
    let json2 = try JSON(string: """
      {
        "num": 1,
        "obj": null
      }
    """)
    let test2: Test = try json2.coerce()
    XCTAssertEqual(json, json2)
    XCTAssertEqual(test, test2)
  }
  
  func testNilCodableInit() throws {
    let test = Test(num: 1, obj: nil)
    let json = try JSON(test)
    let json2 = try JSON(string: """
      {
        "num": 1
      }
    """)
    let test2: Test = try json2.coerce()
    XCTAssertEqual(json, json2)
    XCTAssertEqual(test, test2)
  }
  
  func testExampleWithNull() throws {
    let json = try JSON(string: """
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "const": null
      }
    """)
    let json2: JSON = [
      "$schema" : "https://json-schema.org/draft/2020-12/schema",
      "const" : nil
    ]
    XCTAssertEqual(json, json2)
  }

}
