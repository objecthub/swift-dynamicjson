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

///
/// Result container for JSON schema validators. Currently, `JSONSchemaValidationResults`
/// values primarily collect errors and format annotations.
///
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
  
  /// Location of the current validator invocation. At the top level, this is always
  /// `.root`. This location is used internally to merge results.
  private let location: JSONLocation
  
  /// Errors found by the validator.
  public private(set) var errors: [Annotation<ValidationError>]
  
  /// Format annotations. These are always collected, no matter whether the
  /// `format-annotation` vocabulary is enabled or not. If it is enabled, then the
  /// constraints that are not valid can also be found under `errors`.
  public private(set) var formatConstraints: [Annotation<FormatConstraint>]
  
  /// The evaluated properties of an object. Used primarily internally.
  public private(set) var evaluatedProperties: Set<String>
  
  /// The evaluated items of an array. Used primarily internally.
  public private(set) var evaluatedItems: Set<Int>
  
  ///  Initializes a new, empty `JSONSchemaValidationResults` value for the given
  ///  location.
  public init(for location: JSONLocation) {
    self.location = location
    self.errors = []
    self.formatConstraints = []
    self.evaluatedProperties = []
    self.evaluatedItems = []
  }
  
  /// Did the validator succeed and the value is considered valid? If false, at least
  /// one error was found.
  public var isValid: Bool {
    return self.errors.isEmpty
  }
  
  /// Used internally to flag errors.
  public mutating func flag(error reason: Reason,
                            for value: LocatedJSON,
                            schema: JSONSchema,
                            at location: JSONLocation) {
    self.errors.append(Annotation(value: value,
                                  location: location,
                                  message: ValidationError(schema: schema, reason: reason)))
  }
  
  /// Used internally to flag format annotations.
  public mutating func flag(format: String,
                            valid: Bool?,
                            for value: LocatedJSON,
                            schema: JSONSchema,
                            at location: JSONLocation) {
    self.formatConstraints.append(Annotation(value: value,
                                             location: location,
                                             message: FormatConstraint(format: format, valid: valid)))
  }
  
  /// Used internally to declare a property to be evaluated.
  public mutating func evaluted(property: String) {
    self.evaluatedProperties.insert(property)
  }
  
  /// Used internally to declare an array item to be evaluated.
  public mutating func evaluted(item: Int) {
    self.evaluatedItems.insert(item)
  }
  
  /// Merges another `JSONSchemaValidationResults` value into this value, declaring
  /// `item` to be evaluated.
  public mutating func include(_ other: JSONSchemaValidationResults, for item: Int) {
    self.include(other)
    self.evaluted(item: item)
  }
  
  /// Merges another `JSONSchemaValidationResults` value into this value, declaring
  /// `member` to be evaluated.
  public mutating func include(_ other: JSONSchemaValidationResults, for member: String) {
    self.include(other)
    self.evaluted(property: member)
  }
  
  /// Merges another `JSONSchemaValidationResults` value into this value if the other
  /// value is valid, declaring `item` to be evaluated.
  public mutating func include(ifValid other: JSONSchemaValidationResults, for item: Int) -> Bool {
    guard other.isValid else {
      return false
    }
    self.include(other, for: item)
    return true
  }
  
  /// Merges another `JSONSchemaValidationResults` value into this value if the other
  /// value is valid, declaring `member` to be evaluated.
  public mutating func include(ifValid other: JSONSchemaValidationResults, for member: String) -> Bool {
    guard other.isValid else {
      return false
    }
    self.include(other, for: member)
    return true
  }
  
  /// Merges another `JSONSchemaValidationResults` value into this value if the other
  /// value is valid.
  public mutating func include(ifValid other: JSONSchemaValidationResults) -> Bool {
    guard other.isValid else {
      return false
    }
    self.include(other)
    return true
  }
  
  /// Merges another `JSONSchemaValidationResults` value into this value.
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
  
  /// Textual description of this results value.
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
    if !self.formatConstraints.isEmpty {
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
