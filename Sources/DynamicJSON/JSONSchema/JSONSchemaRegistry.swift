//
//  JSONSchemaRegistry.swift
//  DynamicJSON
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

public class JSONSchemaRegistry {
  
  public static let `default` = JSONSchemaRegistry()
  
  /// The default dialect used by this registry
  public let defaultDialect: JSONSchemaDialect
  
  /// Maps meta-schema URIs (i.e. $schema) to dialects
  public private(set) var dialects: [URL : JSONSchemaDialect]
  
  /// Maps schema identifiers (i.e. $id) to schema
  public private(set) var resources: [URL : JSONSchemaResource]
  
  /// Dynamic extension modules providing new JSON schema resources
  private var providers: [JSONSchemaProvider]
  
  /// Collection of errors raised by functionality provided by `JSONSchemaRegistry`.
  public enum Error: LocalizedError, CustomStringConvertible {
    case cannotRegisterNonRootResource
    case unknownDialect(URL)
    case unknownResource(URL)
    case schemaWithoutId(JSONSchema)
    case validationDepthExhausted(JSONLocation)
    
    public var description: String {
      switch self {
        case .cannotRegisterNonRootResource:
          return "cannot register non-root JSON schema resource"
        case .unknownDialect(let uri):
          return "unsupported dialect \(uri)"
        case .unknownResource(let uri):
          return "unknown JSON schema resource \(uri)"
        case .schemaWithoutId(let schema):
          if let title = schema.title {
            return "schema \"\(title)\" does not provide an id"
          } else {
            return "schema does not provide an id"
          }
        case .validationDepthExhausted(let location):
          return "validation depth exhausted at location \(location)"
      }
    }
    
    public var errorDescription: String? {
      return self.description
    }
    
    public var failureReason: String? {
      switch self {
        case .unknownDialect(_):
          return "dialect error"
        case .unknownResource(_), .cannotRegisterNonRootResource, .schemaWithoutId(_):
          return "schema error"
        case .validationDepthExhausted(_):
          return "validation error"
      }
    }
  }
  
  public init(defaultDialect: JSONSchemaDialect = .draft2020) {
    self.defaultDialect = defaultDialect
    self.dialects = [defaultDialect.uri : defaultDialect]
    self.resources = [:]
    self.providers = []
  }
  
  public init(defaultDialect: JSONSchemaDialect = .draft2020,
              dialects: [JSONSchemaDialect] = [],
              resources: [JSONSchemaResource] = [],
              providers: [JSONSchemaProvider] = []) throws {
    var dialectMap: [URL : JSONSchemaDialect] = [defaultDialect.uri : defaultDialect]
    for dialect in dialects {
      dialectMap[dialect.uri] = dialect
    }
    var resourceMap: [URL : JSONSchemaResource] = [:]
    for resource in resources {
      guard let id = resource.id else {
        throw Error.schemaWithoutId(resource.schema)
      }
      resourceMap[id] = resource
    }
    self.defaultDialect = defaultDialect
    self.dialects = dialectMap
    self.resources = resourceMap
    self.providers = providers
  }
  
  public func register(dialect: JSONSchemaDialect) {
    self.dialects[dialect.uri] = dialect
  }
  
  public func register(resource: JSONSchemaResource) throws {
    guard !resource.schema.isBoolean else {
      return
    }
    guard resource.isRoot else {
      throw Error.schemaWithoutId(resource.schema)
    }
    for nested in resource.nestedResources {
      if let nestedId = nested.id?.normalizedURL {
        self.resources[nestedId] = nested
      }
    }
  }
  
  public func register(provider: JSONSchemaProvider) {
    self.providers.append(provider)
  }
  
  @discardableResult
  public func loadSchema(from url: URL) throws -> JSONSchemaResource {
    let resource = try JSONSchemaResource(url: url)
    try self.register(resource: resource)
    return resource
  }
  
  /// Entry point for a new validator for on a given JSON schema resource. `dialect` is
  /// the default dialect used if a schema resource does not define one.
  public func validator(for root: JSONSchemaResource,
                        dialect: JSONSchemaDialect? = nil) throws -> JSONSchemaValidator {
    try self.register(resource: root)
    //print(root.debugDescription)
    return try self.validator(at: .root, base: root, dialect: dialect)
  }
  
  /// Return validator for a schema referenced by `uri` in the context of JSON schema
  /// resource `base` at `location` (relative to the root JSON schema). `dialect` is the
  /// default schema dialect to be used.
  public func validator(for uri: URL,
                        at location: JSONLocation = .root,
                        base resource: JSONSchemaResource?,
                        dialect: JSONSchemaDialect? = nil) throws -> JSONSchemaValidator {
    var base = resource
    // Determine base URI and fragment
    let id = resource?.uri(relative: uri) ?? uri
    let (baseUri, fragment) = id.extractFragment()
    if resource == nil || !baseUri.lastPathComponent.isEmpty {
      // Get JSON schema resource via the first matching provider, if it is not available yet
      if self.resources[baseUri] == nil {
        for provider in self.providers {
          if let resource = provider.resource(for: baseUri) {
            self.resources[baseUri] = resource
            break
          }
        }
      }
      // Verify that a resource is available
      guard let resource = self.resources[baseUri] else {
        throw Error.unknownResource(id)
      }
      base = resource
    }
    // Resolve fragment
    if let resource = base {
      let target = try resource.resolve(fragment: fragment)
      // Return validator for the resolved schema resource
      return try self.validator(at: location, base: target, dialect: dialect)
    } else {
      throw Error.unknownResource(id)
    }
  }
  
  /// Return validator for `schema` at `location` (relative to the root JSON schema) within
  /// the context of JSON schema resource `base`. `dialect` is the default schema dialect
  /// to be used.
  public func validator(at location: JSONLocation = .root,
                        base: JSONSchemaResource,
                        dialect: JSONSchemaDialect? = nil) throws -> JSONSchemaValidator {
    guard location.segmentCount < 100 else {
      throw Error.validationDepthExhausted(location)
    }
    let schema = base.schema
    if let dialect, schema.schema == nil {
      return dialect.validator(for: schema, at: location, base: base, using: self)
    } else {
      let dialectUri = schema.schema ?? self.defaultDialect.uri
      guard let dialect = self.dialects[dialectUri] else {
        throw Error.unknownDialect(dialectUri)
      }
      return dialect.validator(for: schema, at: location, base: base, using: self)
    }
  }
  
  /// Return validator for `schema` at `location` (relative to the root JSON schema) within
  /// the context of JSON schema resource `base`. `dialect` is the default schema dialect
  /// to be used.
  public func validator(for schema: JSONSchema,
                        at location: JSONLocation = .root,
                        base resource: JSONSchemaResource?,
                        dialect: JSONSchemaDialect? = nil) throws -> JSONSchemaValidator {
    guard location.segmentCount < 100 else {
      throw Error.validationDepthExhausted(location)
    }
    var base = resource
    // Determine a potentially new base schema resource
    if let id = schema.id {
      // Determine base URI and fragment
      let global = resource?.uri(relative: id) ?? id
      let (baseUri, fragment) = global.extractFragment()
      // TODO: Flag if fragment is not nil?
      if let resource = self.resources[baseUri] {
        base = resource
      } else {
        for provider in self.providers {
          if let resource = provider.resource(for: baseUri) {
            self.resources[baseUri] = resource
            base = self.resources[baseUri] ?? base
            break
          }
        }
      }
    }
    if let dialect, schema.schema == nil {
      return dialect.validator(for: schema,
                               at: location,
                               base: base ?? JSONSchemaResource(nested: schema),
                               using: self)
    } else {
      let dialectUri = schema.schema ?? self.defaultDialect.uri
      guard let dialect = self.dialects[dialectUri] else {
        throw Error.unknownDialect(dialectUri)
      }
      return dialect.validator(for: schema,
                               at: location,
                               base: base ?? JSONSchemaResource(nested: schema),
                               using: self)
    }
  }
}
