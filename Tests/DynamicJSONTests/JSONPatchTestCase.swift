//
//  JSONPatchTestCase.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 04/04/2024.
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

class JSONPatchTestCase: XCTestCase {
  
  enum JSONPatchTestError: Error {
    case testSuiteNotFound
  }
  
  open var directory: String? {
    return nil
  }
  
  public func loadComplianceTests(from filename: String) throws -> JSONPatchComplianceTests {
    let bundle = Bundle(for: type(of: self))
    if let url = bundle.url(forResource: filename,
                            withExtension: "json",
                            subdirectory: self.directory) {
      let data = try Data(contentsOf: url)
      return try JSONDecoder().decode(JSONPatchComplianceTests.self, from: data)
    } else {
      let url = URL(fileURLWithPath: "Tests/DynamicJSONTests/ComplianceTests/\(self.directory ?? "")\(filename).json")
      if FileManager.default.fileExists(atPath: url.path) {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(JSONPatchComplianceTests.self, from: data)
      } else {
        throw JSONPatchTestError.testSuiteNotFound
      }
    }
  }
  
  public func execute(name: String, tests: JSONPatchComplianceTests) {
    for test in tests {
      let title = test.comment ?? test.doc.description
      print("✅ \(name)/\(title)")
      if !(test.disabled ?? false) {
        do {
          if let patch: JSONPatch = try? test.patch.coerce() {
            let result = try test.doc.applying(patch: patch)
            if let expected = test.expected {
              XCTAssertEqual(result, expected, "🛑 \(name)/\(title): mismatch")
            } else if let error = test.error {
              XCTFail("🛑 \(name)/\(title)/\(error): valid but should fail")
            }
          } else if test.error != nil {
              // nothing to do
          } else if let expected = test.expected {
            XCTFail("🛑 \(name)/\(title): failed but should have succeeded with \(expected)")
          }
        } catch let e {
          if test.error == nil {
            XCTFail("🛑 \(name)/\(title): failed with \(e.localizedDescription); document: \(test.doc)")
          }
        }
      }
    }
  }
  
  public func execute(suite filename: String) {
    do {
      let complianceTests = try self.loadComplianceTests(from: filename)
      self.execute(name: filename, tests: complianceTests)
    } catch let e {
      XCTFail("🛑 \(filename): cannot load JSONPatch test suite (\(String(describing: e)))")
    }
  }
}
