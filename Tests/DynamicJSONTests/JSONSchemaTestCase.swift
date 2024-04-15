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
  
  public func execute(name: String,
                      tests: JSONSchemaComplianceTests,
                      registry: JSONSchemaRegistry) {
    for test in tests {
      do {
        print("✅ \(name)/\(test.description)")
        if test.ignore ?? false {
          // Don't do anything
        } else {
          let schema = test.schema
          for testCase in test.tests {
            if testCase.ignore ?? false {
              print("  • [ignored] \(testCase.description)")
            } else {
              print("  • \(testCase.description)")
              let result = try testCase.data.validate(with: schema, using: registry)
              if testCase.valid != result.isValid {
                if testCase.valid {
                  XCTFail("🛑 \(name)/\(test.description)/\(testCase.description): \(result)")
                } else {
                  XCTFail("🛑 \(name)/\(test.description)/\(testCase.description): valid but should fail")
                }
              }
            }
          }
        }
      } catch let e {
        XCTFail("🛑 \(name)/\(test.description): validation failed (\(e.localizedDescription))")
      }
    }
  }
  
  public func execute(suite filename: String, registry: JSONSchemaRegistry? = nil) {
    do {
      let complianceTests = try self.loadComplianceTests(from: filename)
      let registry = registry ?? JSONSchemaRegistry()
      self.execute(name: filename, tests: complianceTests, registry: registry)
    } catch let e {
      XCTFail("🛑 \(filename): cannot load JSONSchema test suite (\(String(describing: e)))")
    }
  }
  
  internal func makeRegistry() -> JSONSchemaRegistry {
    let testUri = JSONSchemaIdentifier(string: "http://localhost:1234/")!
    let schemaUri = JSONSchemaIdentifier(string: "https://json-schema.org/draft/2020-12/")!
    let registry = self.makeNewRegistry()
    let bundle = Bundle(for: type(of: self))
    if let dir = bundle.url(forResource: "remotes",
                            withExtension: nil,
                            subdirectory: "JSONSchema") {
      registry.register(provider: .files(from: dir, base: testUri))
    } else {
      let dir = URL(fileURLWithPath: "Tests/DynamicJSONTests/ComplianceTests/JSONSchema/remotes/",
                    isDirectory: true)
      registry.register(provider: .files(from: dir, base: testUri))
    }
    if let dir = bundle.url(forResource: "2020-12",
                            withExtension: nil,
                            subdirectory: "JSONSchema") {
      registry.register(provider: .files(from: dir, base: schemaUri))
    } else {
      let dir = URL(fileURLWithPath: "Tests/DynamicJSONTests/ComplianceTests/JSONSchema/2020-12/",
                    isDirectory: true)
      registry.register(provider: .files(from: dir, base: schemaUri))
    }
    return registry
  }
  
  open func makeNewRegistry() -> JSONSchemaRegistry {
    return JSONSchemaRegistry()
  }
}
