//
//  JSONPathComplianceSuite.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 06/03/2024.
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
