//
//  JSONSchemaValidationResult.swift
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


/// Protocol defining type for annotation messages.
public protocol AnnotationMessage {
  func description(value: LocatedJSON, location: JSONLocation) -> String
}

/// Protocol specifying a failure reason.
public protocol FailureReason {
  var reason: String { get }
}

///
/// Result container for JSON schema validators. Currently, `JSONSchemaValidationResult`
/// values primarily collect errors, format and meta annotations, as well as defaults.
///
public struct JSONSchemaValidationResult: CustomStringConvertible {
  
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
  
  public struct ValidationError: AnnotationMessage {
    public let schema: JSONSchema
    public let reason: FailureReason
    
    public func description(value: LocatedJSON, location: JSONLocation) -> String {
      return "value \(value) not matching schema \(self.schema.id?.string ?? "") at \(location); " +
             "reason: \(self.reason.reason)"
    }
  }
  
  public struct MetaTags: OptionSet, AnnotationMessage {
    public static let deprecated = MetaTags(rawValue: 1 << 0)
    public static let readOnly = MetaTags(rawValue: 1 << 1)
    public static let writeOnly = MetaTags(rawValue: 1 << 2)
    
    public let rawValue: UInt
    
    public init(rawValue: UInt = 0) {
      self.rawValue = rawValue
    }
    
    public func description(value: LocatedJSON, location: JSONLocation) -> String {
      var strs: [String] = []
      if self.contains(.deprecated) {
        strs.append("deprecated")
      }
      if self.contains(.readOnly) {
        strs.append("readOnly")
      }
      if self.contains(.writeOnly) {
        strs.append("writeOnly")
      }
      return "meta tags for value \(value) at location \(location): \(strs.joined(separator: ", "))"
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
  
  public enum DefaultPropagationMode {
    case suppress
    case merge
    case altenative
  }
  
  /// Location of the current validator invocation. At the top level, this is always
  /// `.root`. This location is used internally to merge results.
  private let location: JSONLocation
  
  /// Errors found by the validator.
  public private(set) var errors: [Annotation<ValidationError>]
  
  /// Meta tag annotations denoting what values were deprecated, read-only, or write-only.
  public private(set) var tags: [Annotation<MetaTags>]
  
  /// Format annotations. These are always collected, no matter whether the
  /// `format-annotation` vocabulary is enabled or not. If it is enabled, then the
  /// constraints that are not valid can also be found under `errors`.
  public private(set) var formatConstraints: [Annotation<FormatConstraint>]
  
  /// Default annotations. Set of defined defaults for the validated JSON value.
  /// If `default` is `nil`, then no default was provided. If `default` is the empty
  /// array, the determined defaults contradict each other, i.e. no default exists
  /// which meets all relevant `default` annotations.
  public private(set) var `defaults`: [JSONLocation : (exists: Bool, values: Set<JSON>)]
  
  /// The evaluated properties of an object. Used primarily internally.
  public private(set) var evaluatedProperties: Set<String>
  
  /// The evaluated items of an array. Used primarily internally.
  public private(set) var evaluatedItems: Set<Int>
  
  ///  Initializes a new, empty `JSONSchemaValidationResult` value for the given
  ///  location.
  public init(for location: JSONLocation) {
    self.location = location
    self.errors = []
    self.tags = []
    self.formatConstraints = []
    self.defaults = [:]
    self.evaluatedProperties = []
    self.evaluatedItems = []
  }
  
  /// Did the validator succeed and the value is considered valid? If false, at least
  /// one error was found.
  public var isValid: Bool {
    return self.errors.isEmpty
  }
  
  public var nonexistingDefaults: [JSONLocation : Set<JSON>] {
    var res: [JSONLocation : Set<JSON>] = [:]
    for (location, (exists, defaults)) in self.defaults where !exists {
      res[location] = defaults
    }
    return res
  }
  
  /// Returns a JSON patch object encapsulating all default additions determined by the
  /// validator. If multiple defaults are possible for one location, a random one is chosen
  /// and included in the patch object.
  public var defaultPatch: JSONPatch {
    var operations: [JSONPatchOperation] = []
    for (location, (exists, defaults)) in self.defaults where !exists {
      if let pointer = location.pointer, let `default` = defaults.first {
        operations.append(.add(pointer, `default`))
      }
    }
    return JSONPatch(operations: operations)
  }
  
  /// Used to flag errors by validators.
  public mutating func flag(error reason: FailureReason,
                            for value: LocatedJSON,
                            schema: JSONSchema,
                            at location: JSONLocation) {
    self.errors.append(Annotation(value: value,
                                  location: location,
                                  message: ValidationError(schema: schema, reason: reason)))
  }
  
  /// Used to flag meta tag annotations by validators.
  public mutating func flag(tags: MetaTags,
                            for value: LocatedJSON,
                            schema: JSONSchema,
                            at location: JSONLocation) {
    self.tags.append(Annotation(value: value,
                                location: location,
                                message: tags))
  }
  
  /// Used to flag format annotations by validators.
  public mutating func flag(format: String,
                            valid: Bool?,
                            for value: LocatedJSON,
                            schema: JSONSchema,
                            at location: JSONLocation) {
    self.formatConstraints.append(Annotation(value: value,
                                             location: location,
                                             message: FormatConstraint(format: format, valid: valid)))
  }
  
  /// Used to flag default annotations by validators.
  public mutating func flag(default: JSON,
                            for value: LocatedJSON,
                            schema: JSONSchema,
                            at location: JSONLocation) {
    self.defaults[self.location] = self.merge(default: `default`, exists: value.exists)
  }
  
  /// Used by validators to declare a property to be evaluated.
  public mutating func evaluted(property: String) {
    self.evaluatedProperties.insert(property)
  }
  
  /// Used by validators to declare an array item to be evaluated.
  public mutating func evaluted(item: Int) {
    self.evaluatedItems.insert(item)
  }
  
  /// Merges another `JSONSchemaValidationResult` value into this value, declaring
  /// `item` to be evaluated.
  public mutating func include(_ other: JSONSchemaValidationResult, for item: Int) {
    self.include(other)
    self.evaluted(item: item)
  }
  
  /// Merges another `JSONSchemaValidationResult` value into this value, declaring
  /// `member` to be evaluated.
  public mutating func include(_ other: JSONSchemaValidationResult, for member: String) {
    self.include(other)
    self.evaluted(property: member)
  }
  
  /// Merges another `JSONSchemaValidationResult` value into this value if the other
  /// value is valid, declaring `item` to be evaluated.
  public mutating func include(ifValid other: JSONSchemaValidationResult, for item: Int) -> Bool {
    guard other.isValid else {
      self.merge(defaults: other.defaults, mode: .merge)
      return false
    }
    self.include(other, for: item)
    return true
  }
  
  /// Merges another `JSONSchemaValidationResult` value into this value if the other
  /// value is valid, declaring `member` to be evaluated.
  public mutating func include(ifValid other: JSONSchemaValidationResult, for member: String) -> Bool {
    guard other.isValid else {
      self.merge(defaults: other.defaults, mode: .merge)
      return false
    }
    self.include(other, for: member)
    return true
  }
  
  /// Merges another `JSONSchemaValidationResult` value into this value if the other
  /// value is valid.
  public mutating func include(ifValid other: JSONSchemaValidationResult,
                               propagateDefault: DefaultPropagationMode) -> Bool {
    guard other.isValid else {
      self.merge(defaults: other.defaults, mode: propagateDefault)
      return false
    }
    self.include(other, mode: propagateDefault)
    return true
  }
  
  /// Merges another `JSONSchemaValidationResult` value into this value.
  @discardableResult
  public mutating func include(_ other: JSONSchemaValidationResult,
                               mode: DefaultPropagationMode = .merge) -> JSONSchemaValidationResult {
    self.errors.append(contentsOf: other.errors)
    self.formatConstraints.append(contentsOf: other.formatConstraints)
    self.merge(defaults: other.defaults, mode: mode)
    if self.location == other.location {
      self.evaluatedProperties.formUnion(other.evaluatedProperties)
      self.evaluatedItems.formUnion(other.evaluatedItems)
    }
    return other
  }
  
  /// Merges the value of a `default` keyword into the existing set of defaults
  private mutating func merge(default other: JSON, exists: Bool) -> (Bool, Set<JSON>) {
    if let (cexists, current) = self.defaults[self.location] {
      var new: Set<JSON> = []
      for d in current {
        if let merged = d.merging(value: other) {
          new.insert(merged)
        }
      }
      return (exists || cexists, new)
    } else {
      return (exists, [other])
    }
  }
  
  /// Merges two default sets
  private mutating func merge(_ current: (Bool, Set<JSON>),
                              with others: (Bool, Set<JSON>)?,
                              mode: DefaultPropagationMode) -> (Bool, Set<JSON>) {
    switch mode {
      case .suppress:
        return current
      case .merge:
        if let others {
          var new: Set<JSON> = []
          for d in current.1 {
            for o in others.1 {
              if let merged = d.merging(value: o) {
                new.insert(merged)
              }
            }
          }
          return (current.0 || others.0, new)
        } else {
          return current
        }
      case .altenative:
        if let others {
          var new = current.1
          new.formUnion(others.1)
          return (current.0 || others.0, new)
        } else {
          return current
        }
    }
  }
  
  /// Called by validators to merge default sets (for cases where a full result merging
  /// is not wanted).
  public mutating func merge(defaults others: [JSONLocation : (exists: Bool, values: Set<JSON>)],
                             mode: DefaultPropagationMode) {
    for (location, `default`) in self.defaults {
      self.defaults[location] = self.merge(`default`, with: others[location], mode: mode)
    }
    for (location, `default`) in others where self.defaults[location] == nil {
      self.defaults[location] = `default`
    }
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
