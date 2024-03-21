//
//  JSONSchemaComplianceTest.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 20/03/2024.
//

import Foundation
import DynamicJSON

struct JSONSchemaComplianceTest: Codable {
  let description: String
  let schema: JSONSchema
  let tests: [JSONSchemaVerificationTest]
  let ignore: Bool?
}

struct JSONSchemaVerificationTest: Codable {
  let description: String
  let data: JSON
  let valid: Bool
  let ignore: Bool?
}

typealias JSONSchemaComplianceTests = [JSONSchemaComplianceTest]
