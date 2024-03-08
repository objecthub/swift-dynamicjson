//
//  ComplianceTestSuite.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 05/03/2024.
//

import Foundation
import DynamicJSON

struct JSONPathComplianceTest: Codable {
  var name: String
  var selector: String
  var invalid_selector: Bool?
  var ignore: Bool?
  var document: JSON?
  var result: JSON?
}

struct JSONPathComplianceTests: Codable {
  var tests: [JSONPathComplianceTest]
}
