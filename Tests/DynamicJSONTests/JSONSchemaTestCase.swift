//
//  JSONSchemaTestCase.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 20/03/2024.
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

class JSONSchemaTestCase: XCTestCase {
  
  enum JSONSchemaTestError: Error {
    case testSuiteNotFound
  }
  
  open var directory: String? {
    return nil
  }
  
  public func loadComplianceTests(from filename: String) throws -> JSONSchemaComplianceTests {
    let bundle = Bundle(for: type(of: self))
    if let url = bundle.url(forResource: filename,
                            withExtension: "json",
                            subdirectory: self.directory) {
      let data = try Data(contentsOf: url)
      return try JSONDecoder().decode(JSONSchemaComplianceTests.self, from: data)
    } else {
      let url = URL(fileURLWithPath: "Tests/DynamicJSONTests/ComplianceTests/\(self.directory ?? "")\(filename).json")
      if FileManager.default.fileExists(atPath: url.path) {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(JSONSchemaComplianceTests.self, from: data)
      } else {
        throw JSONSchemaTestError.testSuiteNotFound
      }
    }
  }
  
  private func parse(_ str: String) -> JSONPath? {
    var parser = JSONPathParser(string: str)
    return try? parser.parse()
  }
  
  public func execute(name: String, tests: JSONSchemaComplianceTests) {
    // print("───────────────────────────────────────────────────────────────────────")
    // print(name)
    // print("───────────────────────────────────────────────────────────────────────")
    for test in tests {
      do {
        print("✅ \(name)/\(test.description)")
        if test.ignore ?? false {
          // Don't do anything
        } else {
          let schema = test.schema
          for testCase in test.tests {
            print("  • \(testCase.description)")
            let document = testCase.data
            // XCTAssertEqual(computed, result, "🛑 \(name)/\(test.name): value mismatch")
          }
        }
      }// catch let e {
      //  XCTFail("🛑 \(name)/\(test.name): query failed (\(e.localizedDescription))")
      // }
    }
  }
  
  public func execute(suite filename: String) {
    do {
      let complianceTests = try self.loadComplianceTests(from: filename)
      self.execute(name: filename, tests: complianceTests)
    } catch let e {
      XCTFail("🛑 \(filename): cannot load JSONSchema test suite (\(e.localizedDescription))")
    }
  }
}
