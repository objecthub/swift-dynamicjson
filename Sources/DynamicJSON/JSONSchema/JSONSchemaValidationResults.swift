//
//  JSONSchemaValidationResults.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 01/04/2024.
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

public struct JSONSchemaValidationResults: CustomStringConvertible {
  
  public protocol AnnotationMessage {
    func description(value: LocatedJSON, location: JSONLocation) -> String
  }
  
  public struct Annotation<Message: AnnotationMessage>: CustomStringConvertible {
    public let value: LocatedJSON
    public let location: JSONLocation
    public let message: Message
    
    public init(value: LocatedJSON,
                location: JSONLocation,
                message: Message) {
      self.value = value
      self.location = location
      self.message = message
    }
    
    public var description: String {
      return message.description(value: self.value, location: self.location)
    }
  }
  
  public protocol Reason {
    var reason: String { get }
  }
  
  public struct ValidationError: AnnotationMessage {
    public let schema: JSONSchema
    public let reason: Reason
    
    public func description(value: LocatedJSON, location: JSONLocation) -> String {
      return "value \(value) not matching schema \(self.schema.id?.string ?? "") at \(location); " +
             "reason: \(self.reason.reason)"
    }
  }
  
  public struct FormatConstraint: AnnotationMessage {
    public let format: String
    public let valid: Bool?
    
    public func description(value: LocatedJSON, location: JSONLocation) -> String {
      return "string \(value) needs to conform with format '\(self.format)' at location " +
             "\(location)" + (valid == nil ? "" : valid! ? "; valid" : "; invalid")
    }
  }
  
  private let location: JSONLocation
  public private(set) var errors: [Annotation<ValidationError>]
  public private(set) var formatConstraints: [Annotation<FormatConstraint>]
  public private(set) var evaluatedProperties: Set<String>
  public private(set) var evaluatedItems: Set<Int>
  
  public init(for location: JSONLocation) {
    self.location = location
    self.errors = []
    self.formatConstraints = []
    self.evaluatedProperties = []
    self.evaluatedItems = []
  }
  
  public var isValid: Bool {
    return self.errors.isEmpty
  }
  
  public mutating func flag(error reason: Reason,
                            for value: LocatedJSON,
                            schema: JSONSchema,
                            at location: JSONLocation) {
    self.errors.append(Annotation(value: value,
                                  location: location,
                                  message: ValidationError(schema: schema, reason: reason)))
  }
  
  public mutating func flag(format: String,
                            valid: Bool?,
                            for value: LocatedJSON,
                            schema: JSONSchema,
                            at location: JSONLocation) {
    self.formatConstraints.append(Annotation(value: value,
                                             location: location,
                                             message: FormatConstraint(format: format, valid: valid)))
  }
  
  public mutating func evaluted(property: String) {
    self.evaluatedProperties.insert(property)
  }
  
  public mutating func evaluted(item: Int) {
    self.evaluatedItems.insert(item)
  }
  
  public mutating func include(_ other: JSONSchemaValidationResults, for item: Int) {
    self.include(other)
    self.evaluted(item: item)
  }
  
  public mutating func include(_ other: JSONSchemaValidationResults, for member: String) {
    self.include(other)
    self.evaluted(property: member)
  }
  
  public mutating func include(ifValid other: JSONSchemaValidationResults, for item: Int) -> Bool {
    guard other.isValid else {
      return false
    }
    self.include(other, for: item)
    return true
  }
  
  public mutating func include(ifValid other: JSONSchemaValidationResults, for member: String) -> Bool {
    guard other.isValid else {
      return false
    }
    self.include(other, for: member)
    return true
  }
  
  public mutating func include(ifValid other: JSONSchemaValidationResults) -> Bool {
    guard other.isValid else {
      return false
    }
    self.include(other)
    return true
  }
  
  @discardableResult
  public mutating func include(_ other: JSONSchemaValidationResults) -> JSONSchemaValidationResults {
    self.errors.append(contentsOf: other.errors)
    self.formatConstraints.append(contentsOf: other.formatConstraints)
    if self.location == other.location {
      self.evaluatedProperties.formUnion(other.evaluatedProperties)
      self.evaluatedItems.formUnion(other.evaluatedItems)
    }
    return other
  }
  
  public var description: String {
    var res = ""
    if self.errors.isEmpty {
      res += "VALID"
    } else {
      res += "INVALID:"
      var i = 0
      for error in self.errors {
        i += 1
        res += "\n  [\(i)] \(error)"
      }
    }
    if self.formatConstraints.isEmpty {
      res += "\nFORMAT CONSTRAINTS:"
      var i = 0
      for conformance in self.formatConstraints {
        i += 1
        res += "\n  [\(i)] \(conformance)"
      }
    }
    return res
  }
}
