//
//  JSONSchemaFormatSuite.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 13/04/2024.
//

import XCTest
import Foundation
import DynamicJSON

final class JSONSchemaFormatSuite: JSONSchemaTestCase {
  
  public override var directory: String? {
    return "JSONSchema/tests/optional/format/"
  }
  
  private func formatRegistry() -> JSONSchemaRegistry {
    let vocabulary = JSONSchemaDraft2020.Vocabulary(formatValid: true)
    let dialect = JSONSchemaDraft2020.Dialect(vocabulary: vocabulary)
    return JSONSchemaRegistry(defaultDialect: dialect)
  }
  
  func testUnknown() {
    self.execute(suite: "unknown", registry: formatRegistry())
  }
  
  func testDateTime() {
    self.execute(suite: "date-time", registry: formatRegistry())
  }
  
  func testDate() {
    self.execute(suite: "date", registry: formatRegistry())
  }
  
  func testTime() {
    self.execute(suite: "time", registry: formatRegistry())
  }
  
  func testDuration() {
    self.execute(suite: "duration", registry: formatRegistry())
  }
  
  func testEmail() {
    self.execute(suite: "email", registry: formatRegistry())
  }
  
  func testJSONPointer() {
    self.execute(suite: "json-pointer", registry: formatRegistry())
  }
  
  func testRegex() {
    self.execute(suite: "regex", registry: formatRegistry())
  }
  
  func testUUID() {
    self.execute(suite: "uuid", registry: formatRegistry())
  }
  
  func testURI() {
    self.execute(suite: "uri", registry: formatRegistry())
  }
  
  func testURIReference() {
    self.execute(suite: "uri-reference", registry: formatRegistry())
  }
  
  func testIPV4() {
    self.execute(suite: "ipv4", registry: formatRegistry())
  }
  
  func testIPV6() {
    self.execute(suite: "ipv6", registry: formatRegistry())
  }
  
  func testHostname() {
    self.execute(suite: "hostname", registry: formatRegistry())
  }
}
