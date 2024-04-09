//
//  JSONPatchComplianceSuite.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 04/04/2024.
//

import Foundation

final class JSONPatchComplianceSuite: JSONPatchTestCase {
  
  public override var directory: String? {
    return "JSONPatch/"
  }
  
  func testTests() {
    self.execute(suite: "tests")
  }
  
  func testSpecTests() {
    self.execute(suite: "spec_tests")
  }
  
  func testDebug() {
    self.execute(suite: "debug")
  }
}
