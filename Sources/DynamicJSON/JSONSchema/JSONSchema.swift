//
//  JSONSchema.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 18/03/2024.
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

public indirect enum JSONSchema: Codable,
                                 Equatable,
                                 CustomDebugStringConvertible {
  case boolean(Bool)
  case descriptor(JSONSchemaDescriptor)

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let object = try? container.decode(JSONSchemaDescriptor.self) {
      self = .descriptor(object)
    } else if let bool = try? container.decode(Bool.self) {
      self = .boolean(bool)
    } else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: decoder.codingPath,
                              debugDescription: "Invalid JSONSchema encoding"))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
      case .boolean(let bool):
        try container.encode(bool)
      case .descriptor(let descriptor):
        try container.encode(descriptor)
    }
  }
  
  public var isBoolean: Bool {
    switch self {
      case .boolean(_):
        return true
      case .descriptor(_):
        return false
    }
  }
  
  public var id: URL? {
    switch self {
      case .boolean(_):
        return nil
      case .descriptor(let descriptor):
        return descriptor.id
    }
  }
  
  public var schema: URL? {
    switch self {
      case .boolean(_):
        return nil
      case .descriptor(let descriptor):
        return descriptor.schema
    }
  }
  
  public var title: String? {
    switch self {
      case .boolean(_):
        return nil
      case .descriptor(let descriptor):
        return descriptor.title
    }
  }
  
  public var debugDescription: String {
    switch self {
      case .boolean(false):
        return "false"
      case .boolean(true):
        return "true"
      case .descriptor(let descriptor):
        return descriptor.debugDescription
    }
  }
  
  public var schemaObjects: [JSONLocation : JSONSchema] {
    guard case .descriptor(let descriptor) = self else {
      return [:]
    }
    var res: [JSONLocation : JSONSchema] = [:]
    self.insert(into: &res, at: .root, uri: descriptor.id)
    return res
  }
  
  fileprivate func insert(into nested: inout [JSONLocation : JSONSchema],
                          at location: JSONLocation,
                          uri base: URL?) {
    switch self {
      case .boolean(_):
        nested[location] = self
      case .descriptor(var descriptor):
        if let id = descriptor.id {
          descriptor.id = URL(string: id.relativeString, relativeTo: base)?.absoluteURL
        }
        nested[location] = .descriptor(descriptor)
        descriptor.insert(into: &nested, at: location, uri: descriptor.id ?? base)
    }
  }
}

public struct JSONSchemaDescriptor: Codable, Equatable, CustomDebugStringConvertible {
    
  // Core vocabulary meta-schema
  // https://json-schema.org/draft/2020-12/meta/core
  
  public var id: URL?
  public let schema: URL?
  public let anchor: String?
  public let ref: URL?
  public let dynamicRef: URL?
  public let dynamicAnchor: String?
  public let vocabulary: [String : Bool]?
  public let comment: String?
  public let defs: [String : JSONSchema]?
  
  // Applicator vocabulary meta-schema
  // https://json-schema.org/draft/2020-12/meta/applicator
  
  public let prefixItems: [JSONSchema]?
  public let items: JSONSchema?
  public let contains: JSONSchema?
  public let additionalProperties: JSONSchema?
  public let properties: [String : JSONSchema]?
  public let patternProperties: [String : JSONSchema]?
  public let dependentSchemas: [String : JSONSchema]?
  public let propertyNames: JSONSchema?
  public let `if`: JSONSchema?
  public let `then`: JSONSchema?
  public let `else`: JSONSchema?
  public let allOf: [JSONSchema]?
  public let anyOf: [JSONSchema]?
  public let oneOf: [JSONSchema]?
  public let not: JSONSchema?
  
  // Unevaluated applicator vocabulary meta-schema
  // https://json-schema.org/draft/2020-12/meta/unevaluated
  
  public let unevaluatedItems: JSONSchema?
  public let unevaluatedProperties: JSONSchema?
  
  // Validation vocabulary meta-schema
  // https://json-schema.org/draft/2020-12/meta/validation
  
  public let multipleOf: Double?
  public let maximum: Double?
  public let exclusiveMaximum: Double?
  public let minimum: Double?
  public let exclusiveMinimum: Double?
  public let maxLength: UInt?
  public let minLength: UInt?
  public let pattern: String?
  public let maxItems: UInt?
  public let minItems: UInt?
  public let uniqueItems: Bool?
  public let maxContains: UInt?
  public let minContains: UInt?
  public let maxProperties: UInt?
  public let minProperties: UInt?
  public let required: [String]?
  public let dependentRequired: [String : [String]]?
  public let const: JSON?
  public let `enum`: [JSON]?
  public let type: JSONType?
  
  // Meta-data vocabulary meta-schema
  // https://json-schema.org/draft/2020-12/meta/meta-data
  
  public let title: String?
  public let description: String?
  public let `default`: JSON?
  public let deprecated: Bool?
  public let readOnly: Bool?
  public let writeOnly: Bool?
  public let examples: [JSON]?
  
  // Format vocabulary meta-schema for annotation results
  // https://json-schema.org/draft/2020-12/meta/format-annotation
  
  public let format: String?
  
  // Content vocabulary meta-schema
  // https://json-schema.org/draft/2020-12/meta/content
  
  public let contentMediaType: String?
  public let contentEncoding: String?
  public let contentSchema: JSONSchema?
  
  // For backward compatibility
  
  public let definitions: [String : JSONSchema]?
  public let dependencies: [String : JSONSchemaDependency]?
  
  public var debugDescription: String {
    do {
      let json = try JSON(encodable: self)
      if let str = try json.string(formatting: .prettyPrinted, dateEncodingStrategy: .iso8601) {
        return str
      }
    } catch {
    }
    return "{ id = \(self.id?.absoluteString ?? "nil"), ... }"
  }
  
  fileprivate func insert(into nested: inout [JSONLocation : JSONSchema],
                          at location: JSONLocation,
                          uri base: URL?) {
    self.defs?.insert(into: &nested, at: .member(location, "$defs"), uri: base)
    self.prefixItems?.insert(into: &nested, at: .member(location, "prefixItems"), uri: base)
    self.items?.insert(into: &nested, at: .member(location, "items"), uri: base)
    self.contains?.insert(into: &nested, at: .member(location, "contains"), uri: base)
    self.additionalProperties?.insert(into: &nested, at: .member(location, "additionalProperties"), uri: base)
    self.properties?.insert(into: &nested, at: .member(location, "properties"), uri: base)
    self.patternProperties?.insert(into: &nested, at: .member(location, "patternProperties"), uri: base)
    self.dependentSchemas?.insert(into: &nested, at: .member(location, "dependentSchemas"), uri: base)
    self.propertyNames?.insert(into: &nested, at: .member(location, "propertyNames"), uri: base)
    self.if?.insert(into: &nested, at: .member(location, "if"), uri: base)
    self.then?.insert(into: &nested, at: .member(location, "then"), uri: base)
    self.else?.insert(into: &nested, at: .member(location, "else"), uri: base)
    self.allOf?.insert(into: &nested, at: .member(location, "allOf"), uri: base)
    self.anyOf?.insert(into: &nested, at: .member(location, "anyOf"), uri: base)
    self.oneOf?.insert(into: &nested, at: .member(location, "oneOf"), uri: base)
    self.not?.insert(into: &nested, at: .member(location, "not"), uri: base)
    self.unevaluatedItems?.insert(into: &nested, at: .member(location, "unevaluatedItems"), uri: base)
    self.unevaluatedProperties?.insert(into: &nested, at: .member(location, "unevaluatedProperties"), uri: base)
    self.contentSchema?.insert(into: &nested, at: .member(location, "contentSchema"), uri: base)
    self.definitions?.insert(into: &nested, at: .member(location, "definitions"), uri: base)
    self.dependencies?.insert(into: &nested, at: .member(location, "dependencies"), uri: base)
  }
  
  public enum CodingKeys: String, CodingKey {
    case id = "$id"
    case schema = "$schema"
    case anchor = "$anchor"
    case ref = "$ref"
    case dynamicRef = "$dynamicRef"
    case dynamicAnchor = "$dynamicAnchor"
    case vocabulary = "$vocabulary"
    case comment = "$comment"
    case defs = "$defs"
    case prefixItems
    case items
    case contains
    case additionalProperties
    case properties
    case patternProperties
    case dependentSchemas
    case propertyNames
    case `if`
    case `then`
    case `else`
    case allOf
    case anyOf
    case oneOf
    case not
    case unevaluatedItems
    case unevaluatedProperties
    case multipleOf
    case maximum
    case exclusiveMaximum
    case minimum
    case exclusiveMinimum
    case maxLength
    case minLength
    case pattern
    case maxItems
    case minItems
    case uniqueItems
    case maxContains
    case minContains
    case maxProperties
    case minProperties
    case required
    case dependentRequired
    case const
    case `enum`
    case type
    case title
    case description
    case `default`
    case deprecated
    case readOnly
    case writeOnly
    case examples
    case format
    case contentMediaType
    case contentEncoding
    case contentSchema
    case definitions
    case dependencies
  }
}

public indirect enum JSONSchemaDependency: Codable, Equatable {
  case array([String])
  case schema(JSONSchemaDescriptor)
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let object = try? container.decode(JSONSchemaDescriptor.self) {
      self = .schema(object)
    } else if let arr = try? container.decode([String].self) {
      self = .array(arr)
    } else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: decoder.codingPath,
                              debugDescription: "Invalid JSONSchemaDependency encoding"))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
      case .array(let arr):
        try container.encode(arr)
      case .schema(let descriptor):
        try container.encode(descriptor)
    }
  }
}

extension Array<JSONSchema> {
  fileprivate func insert(into nested: inout [JSONLocation : JSONSchema],
                          at location: JSONLocation,
                          uri base: URL?) {
    for i in self.indices {
      self[i].insert(into: &nested, at: .index(location, i), uri: base)
    }
  }
}

extension Dictionary<String, JSONSchema> {
  fileprivate func insert(into nested: inout [JSONLocation : JSONSchema],
                          at location: JSONLocation,
                          uri base: URL?) {
    for (key, value) in self {
      value.insert(into: &nested, at: .member(location, key), uri: base)
    }
  }
}

extension Dictionary<String, JSONSchemaDependency> {
  fileprivate func insert(into nested: inout [JSONLocation : JSONSchema],
                          at location: JSONLocation,
                          uri base: URL?) {
    for (key, value) in self {
      switch value {
        case .array(_):
          break
        case .schema(let descriptor):
          JSONSchema.descriptor(descriptor).insert(into: &nested, at: .member(location, key), uri: base)
      }
    }
  }
}
