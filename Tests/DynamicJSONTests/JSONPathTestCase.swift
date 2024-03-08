//
//  ComplianceTextCase.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 06/03/2024.
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
    guard let url = bundle.url(forResource: filename, withExtension: "json") else {
      throw JSONPathTestError.testSuiteNotFound
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(JSONPathComplianceTests.self, from: data)
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
          var parser = JSONPathParser(string: test.selector)
          XCTAssertThrowsError(try parser.parse(), "🛑 \(name)/\(test.name) did not fail")
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
