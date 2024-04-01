//
//  JSONSchemaValidator.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 22/03/2024.
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

public protocol JSONSchemaValidator {
  func validate(_ instance: LocatedJSON) -> ValidationResult
}

public struct ValidationResult: CustomStringConvertible {
  public let location: JSONLocation
  public private(set) var errors: [ValidationError]
  public private(set) var evaluatedProperties: Set<String>
  public private(set) var evaluatedItems: Set<Int>
  
  public init(for location: JSONLocation) {
    self.location = location
    self.errors = []
    self.evaluatedProperties = []
    self.evaluatedItems = []
  }
  
  public var isValid: Bool {
    return self.errors.isEmpty
  }
  
  public mutating func flag(_ reason: ValidationReason,
                            for value: LocatedJSON,
                            schema: JSONSchema,
                            at location: JSONLocation) {
    self.errors.append(ValidationError(value: value,
                                       location: location,
                                       schema: schema,
                                       reason: reason))
  }
  
  public mutating func evaluted(property: String) {
    self.evaluatedProperties.insert(property)
  }
  
  public mutating func evaluted(item: Int) {
    self.evaluatedItems.insert(item)
  }
  
  public mutating func include(_ other: ValidationResult, for item: Int) {
    self.include(other)
    self.evaluted(item: item)
  }
  
  public mutating func include(_ other: ValidationResult, for member: String) {
    self.include(other)
    self.evaluted(property: member)
  }
  
  @discardableResult
  public mutating func include(_ other: ValidationResult,
                               propagateErrors: Bool = true) -> ValidationResult {
    if propagateErrors {
      self.errors.append(contentsOf: other.errors)
    }
    if self.location == other.location {
      self.evaluatedProperties.formUnion(other.evaluatedProperties)
      self.evaluatedItems.formUnion(other.evaluatedItems)
    }
    return other
  }
  
  public var description: String {
    if self.errors.isEmpty {
      return "valid"
    } else {
      var res = "invalid:"
      var i = 0
      for error in self.errors {
        i += 1
        res += "\n[\(i)] \(error)"
      }
      return res
    }
  }
}

public struct ValidationError: CustomStringConvertible {
  public let value: LocatedJSON
  public let location: JSONLocation
  public let schema: JSONSchema
  public let reason: ValidationReason
  
  public init(value: LocatedJSON,
              location: JSONLocation,
              schema: JSONSchema,
              reason: ValidationReason) {
    self.value = value
    self.location = location
    self.schema = schema
    self.reason = reason
  }
  
  public var description: String {
    return "value \(self.value.value) at \(value.location) not matching " +
           "schema \(self.schema.id?.string ?? ""); reason: \(self.reason)"
  }
}

public protocol ValidationReason {
  var reason: String { get }
}
