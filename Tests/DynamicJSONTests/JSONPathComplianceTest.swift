//
//  JSONPathComplianceTest.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 05/03/2024.
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
