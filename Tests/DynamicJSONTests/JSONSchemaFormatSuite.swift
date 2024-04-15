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
    let vocabulary = JSONSchemaDraft2020.Vocabulary(format: true)
    let dialect = JSONSchemaDraft2020.Dialect(vocabulary: vocabulary)
    return JSONSchemaRegistry(defaultDialect: dialect)
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
}
