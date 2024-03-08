//
//  JSONPathComplianceTestSuite.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 06/03/2024.
//

final class JSONPathComplianceSuite: JSONPathTestCase {

  func testBasic() {
    self.execute(suite: "basic")
  }
  
  func testNameSelector() {
    self.execute(suite: "name_selector")
  }
  
  func testIndexSelector() {
    self.execute(suite: "index_selector")
  }
  
  func testFilter() {
    self.execute(suite: "filter")
  }
}
