//
//  JSONSchemaDraft2020.swift
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

open class JSONSchemaDraft2020: JSONSchemaValidator {
  
  public struct Vocabulary {
    public let core: Bool
    public let applicator: Bool
    public let unevaluated: Bool
    public let validation: Bool
    public let metadata: Bool
    public let format: Bool
    public let content: Bool
    
    public init(core: Bool = true,
                applicator: Bool = true,
                unevaluated: Bool = true,
                validation: Bool = true,
                metadata: Bool = true,
                format: Bool = true,
                content: Bool = true) {
      self.core = core
      self.applicator = applicator
      self.unevaluated = unevaluated
      self.validation = validation
      self.metadata = metadata
      self.format = format
      self.content = content
    }
  }
  
  public struct Dialect: JSONSchemaDialect {
    public static let `default`: Dialect = Dialect()
    public let vocabulary: Vocabulary
    
    public init(vocabulary: Vocabulary = Vocabulary()) {
      self.vocabulary = vocabulary
    }
    
    public var uri: URL {
      return URL(string: "https://json-schema.org/draft/2020-12/schema")!
    }
    
    public func validator(for schema: JSONSchema,
                          in context: JSONSchemaValidationContext) -> JSONSchemaValidator {
      return JSONSchemaDraft2020(dialect: self, context: context, schema: schema)
    }
  }
  
  public enum Reason: JSONSchemaValidationResults.Reason, CustomStringConvertible {
    case validationError(Error)
    case alwaysFails
    case schemaValidatesButShouldFail
    case noneOfTheSchemaValidates
    case tooManySchemaValidate
    case notIntMultipleOf(Int64, Double)
    case notFloatMultipleOf(Double, Double)
    case exceedsIntMaximum(Int64, Double, Bool)
    case exceedsFloatMaximum(Double, Double, Bool)
    case belowIntMinimum(Int64, Double, Bool)
    case belowFloatMinimum(Double, Double, Bool)
    case invalidPattern(String?, String)
    case patternNotMatching(String, String)
    case tooManyArrayItems(UInt, UInt)
    case tooFewArrayItems(UInt, UInt)
    case itemsNotUnique
    case tooManyProperties(UInt, UInt)
    case tooFewProperties(UInt, UInt)
    case propertiesMissing([String])
    case dependentPropertiesMissing(String, [String])
    case valueNotConst
    case valueNotFoundInEnum
    case invalidType(JSONType, JSONType)
    case exceedsMaxLength(String, UInt)
    case lessThanMinLength(String, UInt)
    case containCountMismatch(UInt, UInt, UInt)
    case arrayPrefixInvalid(Int)
    case arrayItemInvalid(Int)
    
    public var reason: String {
      switch self {
        case .validationError(let error):
          return "Validation error: \(error.localizedDescription)"
        case .alwaysFails:
          return "Schema always fails validation"
        case .noneOfTheSchemaValidates:
          return "None of the schema validates"
        case .schemaValidatesButShouldFail:
          return "Schema validates but should fail"
        case .tooManySchemaValidate:
          return "More than one schema validates"
        case .exceedsIntMaximum(let x, let max, let excl):
          return "Integer number \(x) exceeds \(excl ? "exclusive " : "")" +
                 "maximum value of \(max)."
        case .exceedsFloatMaximum(let x, let max, let excl):
          return "Floating-point number \(x) exceeds \(excl ? "exclusive " : "")" +
                 "maximum value of \(max)."
        case .belowIntMinimum(let x, let min, let excl):
          return "Integer number \(x) below \(excl ? "exclusive " : "")minimum value of \(min)."
        case .belowFloatMinimum(let x, let min, let excl):
          return "Floating-point number \(x) below \(excl ? "exclusive " : "")" +
                 "minimum value of \(min)."
        case .notIntMultipleOf(let x, let multipleOf):
          return "Integer number \(x) is not a mutiple of \(multipleOf)"
        case .notFloatMultipleOf(let x, let multipleOf):
          return "Floating-point number \(x) is not a mutiple of \(multipleOf)"
        case .invalidPattern(let str, let pattern):
          if let str {
            return "Could not validate string '\(str)' with erroneous pattern '\(pattern)'"
          } else {
            return "Erroneous regular-expression pattern '\(pattern)'"
          }
        case .patternNotMatching(let str, let pattern):
          return "String '\(str)' does not match pattern '\(pattern)'"
        case .tooManyArrayItems(let count, let max):
          return "Array item count \(count) is more than maximum count of \(max)"
        case .tooFewArrayItems(let count, let min):
          return "Array item count \(count) is less than minimum count of \(min)"
        case .itemsNotUnique:
          return "Array items not unique"
        case .tooManyProperties(let count, let max):
          return "Object property count \(count) is more than maximum count of \(max)"
        case .tooFewProperties(let count, let min):
          return "Object property count \(count) is less than minimum count of \(min)"
        case .propertiesMissing(let props):
          return "Missing required property: \(props.joined(separator: ", "))"
        case .dependentPropertiesMissing(let prop, let others):
          return "Dependencies for property '\(prop)' failed. " +
                 "Missing required properties: \(others.joined(separator: ", "))"
        case .valueNotConst:
          return "Value does not match const"
        case .valueNotFoundInEnum:
          return "Value not found in enum"
        case .invalidType(let expected, let found):
          return "Invalid type; expected \(expected) but found \(found)"
        case .exceedsMaxLength(let str, let maxLength):
          return "String '\(str)' exceeds maximum length of \(maxLength)"
        case .lessThanMinLength(let str, let minLength):
          return "String '\(str)' is less than minimum length of \(minLength)"
        case .containCountMismatch(let matches, let min, let max):
          return "Contains match count \(matches) is outside the required range [\(min); \(max)]"
        case .arrayPrefixInvalid(let index):
          return "Array item at index \(index) does not match the schema prefix"
        case .arrayItemInvalid(let index):
          return "Array item at index \(index) does not match the required schema"
      }
    }
    
    public var description: String {
      return self.reason
    }
  }
  
  public let dialect: Dialect
  public let context: JSONSchemaValidationContext
  public let schema: JSONSchema
  
  public init(dialect: Dialect, context: JSONSchemaValidationContext, schema: JSONSchema) {
    self.dialect = dialect
    self.context = context
    self.schema = schema
  }
  
  open func validateCore(instance: LocatedJSON, result: inout JSONSchemaValidationResults) {
    func flag(_ reason: Reason, for member: String) {
      result.flag(reason, for: instance, schema: self.schema, at: .member(self.context.location, member))
    }
    guard case .descriptor(let descriptor) = self.schema else {
      return
    }
    // if let id = descriptor.id {}
    // if let schema = descriptor.schema {}
    // if let anchor = descriptor.anchor {}
    if let ref = descriptor.ref {
      do {
        let validator = try self.context.validator(for: ref,
                                                   at: .member(self.context.location, "$ref"),
                                                   dialect: dialect)
        result.include(validator.validate(instance))
      } catch let e {
        flag(.validationError(e), for: "$ref")
      }
    }
    if let dynamicRef = descriptor.dynamicRef {
      do {
        let validator = try self.context.validator(for: dynamicRef,
                                                   at: .member(self.context.location, "$dynamicRef"),
                                                   dynamic: true,
                                                   dialect: dialect)
        result.include(validator.validate(instance))
      } catch let e {
        flag(.validationError(e), for: "$dynamicRef")
      }
    }
    // if let dynamicAnchor = descriptor.dynamicAnchor {}
    // if let vocabulary = descriptor.vocabulary {
    //
    // }
    // if let comment = descriptor.comment {}
    // if let defs = descriptor.defs {}
  }
  
  open func validateApplicator(instance: LocatedJSON, result: inout JSONSchemaValidationResults) {
    func flag(_ reason: Reason, for member: String) {
      result.flag(reason, for: instance, schema: self.schema, at: .member(self.context.location, member))
    }
    func validator(for schema: JSONSchema,
                   at member: String, _ member2: String? = nil,
                   index: Int? = nil) -> JSONSchemaValidator? {
      do {
        var location: JSONLocation = .member(self.context.location, member)
        if let member2 {
          location = .member(location, member2)
        }
        if let index, index >= 0 {
          location = .index(location, index)
        }
        return try self.context.validator(for: schema, at: location, dialect: self.dialect)
      } catch let e {
        flag(.validationError(e), for: member)
        return nil
      }
    }
    guard case .descriptor(let descriptor) = self.schema else {
      return
    }
    if let prefixItems = descriptor.prefixItems, case .array(let arr) = instance.value {
      do {
        let location: JSONLocation = .member(self.context.location, "prefixItems")
        for i in 0..<min(prefixItems.count, arr.count) {
          let validator = try self.context.validator(for: prefixItems[i],
                                                     at: .index(location, i),
                                                     dialect: self.dialect)
          if let item = instance.index(i) {
            result.include(validator.validate(item), for: i)
          }
        }
      } catch let e {
        flag(.validationError(e), for: "prefixItems")
      }
    }
    if let items = descriptor.items, case .array(let arr) = instance.value {
      let start = descriptor.prefixItems?.count ?? 0
      if start < arr.count, let validator = validator(for: items, at: "items") {
        for i in start..<arr.count {
          if let item = instance.index(i) {
            result.include(validator.validate(item), for: i)
          }
        }
      }
    }
    if let contains = descriptor.contains, case .array(let arr) = instance.value {
      if let validator = validator(for: contains, at: "contains") {
        var numContains: UInt = 0
        for i in arr.indices {
          if let item = instance.index(i) {
            if result.include(ifValid: validator.validate(item), for: i) {
              numContains += 1
            }
          }
        }
        let maxContains = descriptor.maxContains ?? .max
        let minContains = descriptor.minContains ?? 1
        if numContains < minContains || numContains > maxContains {
          flag(.containCountMismatch(numContains, minContains, maxContains), for: "contains")
        }
      }
    }
    if case .object(let d) = instance.value {
      var validatedMembers: Set<String> = []
      if let properties = descriptor.properties {
        for (member, schema) in properties {
          if let value = instance.member(member),
             let validator = validator(for: schema, at: "properties", member) {
            validatedMembers.insert(member)
            result.include(validator.validate(value), for: member)
          }
        }
      }
      if let patternProperties = descriptor.patternProperties {
        for (pattern, schema) in patternProperties {
          if let expr = try? NSRegularExpression(pattern: pattern) {
            for m in d.keys {
              if expr.matches(in: m, options: .init(), range: NSMakeRange(0, m.count)).count > 0,
                 let value = instance.member(m),
                 let validator = validator(for: schema, at: "properties", m) {
                validatedMembers.insert(m)
                result.include(validator.validate(value), for: m)
              }
            }
          } else {
            flag(.invalidPattern(nil, pattern), for: "pattern")
          }
        }
      }
      if let additionalProperties = descriptor.additionalProperties,
         let validator = validator(for: additionalProperties, at: "additionalProperties") {
        for m in d.keys where !validatedMembers.contains(m) {
          if let value = instance.member(m) {
            result.include(validator.validate(value), for: m)
          }
        }
      }
    }
    if let dependentSchemas = descriptor.dependentSchemas, case .object(let d) = instance.value {
      for (member, schema) in dependentSchemas where d[member] != nil {
        if let validator = validator(for: schema, at: "dependentSchemas", member) {
          result.include(validator.validate(instance))
        }
      }
    }
    if let propertyNames = descriptor.propertyNames,
       case .object(let dict) = instance.value,
       let validator = validator(for: propertyNames, at: "propertyNames") {
      for member in dict.keys {
        result.include(validator.validate(LocatedJSON(root: .string(member))))
      }
    }
    if let `if` = descriptor.if, let condition = validator(for: `if`, at: "if") {
      if result.include(ifValid: condition.validate(instance)) {
        if let then = descriptor.then, let validator = validator(for: then, at: "then") {
          result.include(validator.validate(instance))
        }
      } else if let `else` = descriptor.else, let validator = validator(for: `else`, at: "else") {
        result.include(validator.validate(instance))
      }
    }
    if let allOf = descriptor.allOf {
      for i in allOf.indices {
        if let validator = validator(for: allOf[i], at: "allOf", index: i) {
          result.include(validator.validate(instance))
        }
      }
    }
    if let anyOf = descriptor.anyOf {
      var valid = false
      for i in anyOf.indices {
        if let validator = validator(for: anyOf[i], at: "anyOf", index: i) {
          if result.include(ifValid: validator.validate(instance)) {
            valid = true
          }
        }
      }
      if !valid {
        flag(.noneOfTheSchemaValidates, for: "anyOf")
      }
    }
    if let oneOf = descriptor.oneOf {
      var valid = false
      var flagged = false
      for i in oneOf.indices {
        if let validator = validator(for: oneOf[i], at: "oneOf", index: i) {
          if result.include(ifValid: validator.validate(instance)) {
            if valid && !flagged {
              flag(.tooManySchemaValidate, for: "oneOf")
              flagged = true
            }
            valid = true
          }
        }
      }
      if !valid {
        flag(.noneOfTheSchemaValidates, for: "anyOf")
      }
    }
    if let not = descriptor.not, let validator = validator(for: not, at: "not") {
      if result.include(ifValid: validator.validate(instance)) {
        flag(.schemaValidatesButShouldFail, for: "not")
      }
    }
  }
  
  open func validateUnevaluated(instance: LocatedJSON, result: inout JSONSchemaValidationResults) {
    func flag(_ reason: Reason, for member: String) {
      result.flag(reason, for: instance, schema: self.schema, at: .member(self.context.location, member))
    }
    func validator(for schema: JSONSchema,
                   at member: String, _ member2: String? = nil,
                   index: Int? = nil) -> JSONSchemaValidator? {
      do {
        var location: JSONLocation = .member(self.context.location, member)
        if let member2 {
          location = .member(location, member2)
        }
        if let index, index >= 0 {
          location = .index(location, index)
        }
        return try self.context.validator(for: schema, at: location, dialect: self.dialect)
      } catch let e {
        flag(.validationError(e), for: member)
        return nil
      }
    }
    guard case .descriptor(let descriptor) = self.schema else {
      return
    }
    if let unevaluatedProperties = descriptor.unevaluatedProperties,
       case .object(let dict) = instance.value,
       let validator = validator(for: unevaluatedProperties, at: "unevaluatedProperties") {
      for member in dict.keys where !result.evaluatedProperties.contains(member) {
        if let value = instance.member(member) {
          result.include(validator.validate(value), for: member)
        }
      }
    }
    if let unevaluatedItems = descriptor.unevaluatedItems,
       case .array(let arr) = instance.value,
       let validator = validator(for: unevaluatedItems, at: "unevaluatedItems") {
      for i in arr.indices where !result.evaluatedItems.contains(i) {
        if let value = instance.index(i) {
          result.include(validator.validate(value), for: i)
        }
      }
    }
  }
  
  open func validateValidation(instance: LocatedJSON, result: inout JSONSchemaValidationResults) {
    func flag(_ reason: Reason, for member: String) {
      result.flag(reason, for: instance, schema: self.schema, at: .member(self.context.location, member))
    }
    guard case .descriptor(let descriptor) = self.schema else {
      return
    }
    if let multipleOf = descriptor.multipleOf {
      switch instance.value {
        case .integer(let x):
          if let y = Int64(exactly: multipleOf), x % y != 0 {
            flag(.notIntMultipleOf(x, multipleOf), for: "multipleOf")
          } else {
            let y = Double(x) / multipleOf
            if Foundation.trunc(y) != y {
              flag(.notIntMultipleOf(x, multipleOf), for: "multipleOf")
            }
          }
        case .float(let x):
          let y = x / multipleOf
          if Foundation.trunc(y) != y {
            flag(.notFloatMultipleOf(x, multipleOf), for: "multipleOf")
          }
        default:
          break
      }
    }
    if let max = descriptor.maximum {
      switch instance.value {
        case .integer(let x):
          if let y = Int64(exactly: max), x > y {
            flag(.exceedsIntMaximum(x, max, false), for: "maximum")
          } else if Double(x) > max {
            flag(.exceedsIntMaximum(x, max, false), for: "maximum")
          }
        case .float(let x):
          if x > max {
            flag(.exceedsFloatMaximum(x, max, false), for: "maximum")
          }
        default:
          break
      }
    }
    if let max = descriptor.exclusiveMaximum {
      switch instance.value {
        case .integer(let x):
          if let y = Int64(exactly: max), x >= y {
            flag(.exceedsIntMaximum(x, max, true), for: "exclusiveMaximum")
          } else if Double(x) >= max {
            flag(.exceedsIntMaximum(x, max, true), for: "exclusiveMaximum")
          }
        case .float(let x):
          if x >= max {
            flag(.exceedsFloatMaximum(x, max, true), for: "exclusiveMaximum")
          }
        default:
          break
      }
    }
    if let min = descriptor.minimum {
      switch instance.value {
        case .integer(let x):
          if let y = Int64(exactly: min), x < y {
            flag(.belowIntMinimum(x, min, false), for: "minimum")
          } else if Double(x) < min {
            flag(.belowIntMinimum(x, min, false), for: "minimum")
          }
        case .float(let x):
          if x < min {
            flag(.belowFloatMinimum(x, min, false), for: "minimum")
          }
        default:
          break
      }
    }
    if let min = descriptor.exclusiveMinimum {
      switch instance.value {
        case .integer(let x):
          if let y = Int64(exactly: min), x <= y {
            flag(.belowIntMinimum(x, min, true), for: "exclusiveMinimum")
          } else if Double(x) <= min {
            flag(.belowIntMinimum(x, min, true), for: "exclusiveMinimum")
          }
        case .float(let x):
          if x <= min {
            flag(.belowFloatMinimum(x, min, true), for: "exclusiveMinimum")
          }
        default:
          break
      }
    }
    if let maxLength = descriptor.maxLength,
       case .string(let str) = instance.value,
       str.count > maxLength {
      flag(.exceedsMaxLength(str, maxLength), for: "maxLength")
    }
    if let minLength = descriptor.minLength,
       case .string(let str) = instance.value,
       str.count < minLength {
      flag(.lessThanMinLength(str, minLength), for: "minLength")
    }
    if let pattern = descriptor.pattern, case .string(let str) = instance.value {
      if let expr = try? NSRegularExpression(pattern: pattern) {
        if expr.matches(in: str, options: .init(), range: NSMakeRange(0, str.count)).count == 0 {
          flag(.patternNotMatching(str, pattern), for: "pattern")
        }
      } else {
        flag(.invalidPattern(str, pattern), for: "pattern")
      }
    }
    if let max = descriptor.maxItems, case .array(let arr) = instance.value, arr.count > max  {
      flag(.tooManyArrayItems(UInt(arr.count), max), for: "maxItems")
    }
    if let min = descriptor.minItems, case .array(let arr) = instance.value, arr.count < min  {
      flag(.tooFewArrayItems(UInt(arr.count), min), for: "minItems")
    }
    if let unique = descriptor.uniqueItems, unique, case .array(let arr) = instance.value {
      var set: Set<JSON> = []
      for value in arr {
        if set.contains(value) {
          flag(.itemsNotUnique, for: "uniqueItems")
          break
        } else {
          set.insert(value)
        }
      }
    }
    if let max = descriptor.maxProperties, case .object(let d) = instance.value, d.count > max {
      flag(.tooManyProperties(UInt(d.count), max), for: "maxProperties")
    }
    if let min = descriptor.minProperties, case .object(let d) = instance.value, d.count < min {
      flag(.tooFewProperties(UInt(d.count), min), for: "minProperties")
    }
    if let required = descriptor.required, case .object(let dict) = instance.value {
      let missing = required.filter { dict[$0] == nil }
      if !missing.isEmpty {
        flag(.propertiesMissing(missing), for: "required")
      }
    }
    if let depRequired = descriptor.dependentRequired, case .object(let dict) = instance.value {
      for (m, others) in depRequired {
        if dict[m] != nil {
          let miss = others.filter { dict[$0] == nil }
          if !miss.isEmpty {
            flag(.dependentPropertiesMissing(m, miss), for: "dependentRequired")
          }
        }
      }
    }
    if let const = descriptor.const, const != instance.value {
      flag(.valueNotConst, for: "const")
    }
    if let `enum` = descriptor.enum, !`enum`.contains(instance.value) {
      flag(.valueNotFoundInEnum, for: "enum")
    }
    if let exp = descriptor.type, !instance.value.type.included(in: exp) {
      flag(.invalidType(exp, instance.value.type), for: "type")
    }
  }
  
  open func validateMetadata(instance: LocatedJSON, result: inout JSONSchemaValidationResults) {
    
  }
  
  open func validateFormat(instance: LocatedJSON, result: inout JSONSchemaValidationResults) {
    
  }
  
  open func validateContent(instance: LocatedJSON, result: inout JSONSchemaValidationResults) {
    
  }
  
  open func validate(_ instance: LocatedJSON) -> JSONSchemaValidationResults {
    var result = JSONSchemaValidationResults(for: instance.location)
    // Check if this schema always suceeds or fails
    if case .boolean(let bool) = self.schema {
      if !bool {
        result.flag(Reason.alwaysFails, for: instance, schema: self.schema, at: self.context.location)
      }
      return result
    }
    // Validate supported vocabularies
    if self.dialect.vocabulary.core {
      self.validateCore(instance: instance, result: &result)
    }
    if self.dialect.vocabulary.applicator {
      self.validateApplicator(instance: instance, result: &result)
    }
    if self.dialect.vocabulary.validation {
      self.validateValidation(instance: instance, result: &result)
    }
    if self.dialect.vocabulary.metadata {
      self.validateMetadata(instance: instance, result: &result)
    }
    if self.dialect.vocabulary.format {
      self.validateFormat(instance: instance, result: &result)
    }
    if self.dialect.vocabulary.content {
      self.validateContent(instance: instance, result: &result)
    }
    if self.dialect.vocabulary.unevaluated {
      self.validateUnevaluated(instance: instance, result: &result)
    }
    return result
  }
}
