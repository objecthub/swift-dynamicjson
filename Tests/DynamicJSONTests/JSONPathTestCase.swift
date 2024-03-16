//
//  JSONPathTestCase.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 06/03/2024.
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

import Foundation
import XCTest
import DynamicJSON

class JSONPathTestCase: XCTestCase {
  
  enum JSONPathTestError: Error {
    case testSuiteNotFound
  }
  
  public func loadComplianceTests(from filename: String) throws -> JSONPathComplianceTests {
    let bundle = Bundle(for: type(of: self))
    if let url = bundle.url(forResource: filename, withExtension: "json") {
      let data = try Data(contentsOf: url)
      return try JSONDecoder().decode(JSONPathComplianceTests.self, from: data)
    } else {
      let url = URL(fileURLWithPath: "Tests/DynamicJSONTests/ComplianceTests/JSONPath/\(filename).json")
      if FileManager.default.fileExists(atPath: url.path) {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(JSONPathComplianceTests.self, from: data)
      } else {
        throw JSONPathTestError.testSuiteNotFound
      }
    }
  }
  
  private func parse(_ str: String) -> JSONPath? {
    var parser = JSONPathParser(string: str)
    return try? parser.parse()
  }
  
  public func execute(name: String, tests: [JSONPathComplianceTest]) {
    // print("───────────────────────────────────────────────────────────────────────")
    // print(name)
    // print("───────────────────────────────────────────────────────────────────────")
    for test in tests {
      do {
        print("✅ \(name)/\(test.name)")
        if test.ignore ?? false {
          // Don't do anything
        } else if test.invalid_selector ?? false {
          if let document = test.document {
            XCTAssertThrowsError(try document.query(test.selector),
                                 "🛑 \(name)/\(test.name) did not fail")
          } else {
            var parser = JSONPathParser(string: test.selector)
            XCTAssertThrowsError(try parser.parse(), "🛑 \(name)/\(test.name) did not fail")
          }
        } else if let document = test.document,
                  case .some(.array(let res)) = test.result {
          let result = Set(res)
          let computed = Set(try document.query(test.selector))
          XCTAssertEqual(computed, result, "🛑 \(name)/\(test.name)")
        } else {
          XCTFail("🛑 \(name)/\(test.name): invalid test case")
        }
      } catch let e {
        XCTFail("🛑 \(name)/\(test.name): query failed (\(e.localizedDescription))")
      }
    }
  }
  
  public func execute(suite filename: String) {
    do {
      let complianceTests = try self.loadComplianceTests(from: filename)
      self.execute(name: filename, tests: complianceTests.tests)
    } catch let e {
      XCTFail("🛑 \(filename): cannot load JSONPath test suite (\(e.localizedDescription))")
    }
  }
}
