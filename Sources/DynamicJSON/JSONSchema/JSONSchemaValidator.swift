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
  public private(set) var errors: [ValidationError]
  
  public init() {
    self.errors = []
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
  
  public mutating func include(_ other: ValidationResult) {
    self.errors.append(contentsOf: other.errors)
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
