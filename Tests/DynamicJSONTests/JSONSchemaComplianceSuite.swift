//
//  JSONSchemaComplianceSuite.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 21/03/2024.
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

final class JSONSchemaComplianceSuite: JSONSchemaTestCase {
  
  public override var directory: String? {
    return "JSONSchema/tests/"
  }
  
  func testAdditionalProperties() {
    self.execute(suite: "additionalProperties")
  }

  func testAllOf() {
    self.execute(suite: "allOf")
  }

  func testAnchor() {
    self.execute(suite: "anchor")
  }

  func testAnyOf() {
    self.execute(suite: "anyOf")
  }

  func testBooleanSchema() {
    self.execute(suite: "boolean_schema")
  }

  func testConst() {
    self.execute(suite: "const")
  }

  func testContains() {
    self.execute(suite: "contains")
  }

  func testContent() {
    self.execute(suite: "content")
  }

  func testDefault() {
    self.execute(suite: "default")
  }

  func testDefs() {
    self.execute(suite: "defs")
  }

  func testDependentRequired() {
    self.execute(suite: "dependentRequired")
  }

  func testDependentSchemas() {
    self.execute(suite: "dependentSchemas")
  }

  func testDynamicRef() {
    self.execute(suite: "dynamicRef")
  }

  func testEnum() {
    self.execute(suite: "enum")
  }

  func testExclusiveMaximum() {
    self.execute(suite: "exclusiveMaximum")
  }

  func testExclusiveMinimum() {
    self.execute(suite: "exclusiveMinimum")
  }

  func testFormat() {
    self.execute(suite: "format")
  }

  func testId() {
    self.execute(suite: "id")
  }

  func testIfThenElse() {
    self.execute(suite: "if-then-else")
  }

  func testInfiniteLoopDetection() {
    self.execute(suite: "infinite-loop-detection")
  }

  func testItems() {
    self.execute(suite: "items")
  }

  func testMaxContains() {
    self.execute(suite: "maxContains")
  }

  func testMaximum() {
    self.execute(suite: "maximum")
  }

  func testMaxItems() {
    self.execute(suite: "maxItems")
  }

  func testMaxLength() {
    self.execute(suite: "maxLength")
  }

  func testMaxProperties() {
    self.execute(suite: "maxProperties")
  }

  func testMinContains() {
    self.execute(suite: "minContains")
  }

  func testMinimum() {
    self.execute(suite: "minimum")
  }

  func testMinItems() {
    self.execute(suite: "minItems")
  }

  func testMinLength() {
    self.execute(suite: "minLength")
  }

  func testMinProperties() {
    self.execute(suite: "minProperties")
  }

  func testMultipleOf() {
    self.execute(suite: "multipleOf")
  }

  func testNot() {
    self.execute(suite: "not")
  }

  func testOneOf() {
    self.execute(suite: "oneOf")
  }

  func testPattern() {
    self.execute(suite: "pattern")
  }

  func testPatternProperties() {
    self.execute(suite: "patternProperties")
  }

  func testprefixItems() {
    self.execute(suite: "prefixItems")
  }

  func testProperties() {
    self.execute(suite: "properties")
  }

  func testPropertyNames() {
    self.execute(suite: "propertyNames")
  }

  func testRef() {
    self.execute(suite: "ref")
  }

  func testRefRemote() {
    self.execute(suite: "refRemote")
  }

  func testRequired() {
    self.execute(suite: "required")
  }

  func testType() {
    self.execute(suite: "type")
  }

  func testunevaluatedItems() {
    self.execute(suite: "unevaluatedItems")
  }

  func testUnevaluatedProperties() {
    self.execute(suite: "unevaluatedProperties")
  }

  func testUniqueItems() {
    self.execute(suite: "uniqueItems")
  }

  func testVocabulary() {
    self.execute(suite: "vocabulary")
  }
}
