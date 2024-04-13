//
//  JSONSchemaOptionalSuite.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 10/04/2024.
//

import XCTest

import Foundation
import DynamicJSON

final class JSONSchemaOptionalSuite: JSONSchemaTestCase {
  
  public override var directory: String? {
    return "JSONSchema/tests/optional/"
  }
  
  func testAnchor() {
    self.execute(suite: "anchor")
  }

  /*
  func testBignum() {
    self.execute(suite: "bignum")
  }
  */
  
  func testCrossDraft() {
    self.execute(suite: "cross-draft")
  }

  func testDependenciesCompatibility() {
    self.execute(suite: "dependencies-compatibility")
  }

  func testEcmaScriptRegex() {
    self.execute(suite: "ecmascript-regex")
  }
  
  func testFloatOverflow() {
    self.execute(suite: "float-overflow")
  }
  
  func testFormatAssertion() {
    self.execute(suite: "format-assertion")
  }

  func testId() {
    self.execute(suite: "id")
  }

  func testNoSchema() {
    self.execute(suite: "no-schema")
  }

  func testNonBmpRegex() {
    self.execute(suite: "non-bmp-regex")
  }

  func testRefOfUnknownKeyword() {
    self.execute(suite: "refOfUnknownKeyword")
  }

  func testUnknownKeyword() {
    self.execute(suite: "unknownKeyword")
  }
}
