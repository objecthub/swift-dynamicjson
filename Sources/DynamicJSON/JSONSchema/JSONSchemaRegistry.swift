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

///
/// Class `JSONSchemaRegistry` is used to define an environment of all known JSON
/// schema resources. Every validator application is based on such a schema registry
/// for looking up referenced schema.
///
public class JSONSchemaRegistry {
  
  /// This is a shared, non-thread safe registry that can be used as a quick alternative
  /// for non-production usage to the default of `JSON.validate(with:, using:))` (which
  /// creates a new empty registry for every invocation).
  public static let `default` = DefaultJSONSchemaRegistry()
  
  /// The default dialect used by this registry
  public let defaultDialect: JSONSchemaDialect
  
  /// Maps meta-schema URIs (i.e. $schema) to dialects
  public fileprivate(set) var dialects: [URL : JSONSchemaDialect]
  
  /// Maps schema identifiers (i.e. $id) to schema
  public fileprivate(set) var resources: [JSONSchemaIdentifier : JSONSchemaResource]
  
  /// Dynamic extension modules providing new JSON schema resources
  fileprivate var providers: [JSONSchemaProvider]
  
  /// Collection of errors raised by functionality provided by `JSONSchemaRegistry`.
  public enum Error: LocalizedError, CustomStringConvertible {
    case cannotRegisterNonRootResource(JSONSchema)
    case schemaWithoutId(JSONSchema)
    case unknownSchemaResource(String)
    
    public var description: String {
      switch self {
        case .cannotRegisterNonRootResource(let schema):
          if let title = schema.title {
            return "cannot register non-root JSON schema resource \'\(title)\'"
          } else {
            return "cannot register non-root JSON schema resource"
          }
        case .schemaWithoutId(let schema):
          if let title = schema.title {
            return "schema \"\(title)\" does not provide an id"
          } else {
            return "schema does not provide an id"
          }
        case .unknownSchemaResource(let identifier):
          return "cannot find schema resource identified by: \(identifier)"
          
      }
    }
    
    public var errorDescription: String? {
      return self.description
    }
    
    public var failureReason: String? {
      switch self {
        case .cannotRegisterNonRootResource(_), .schemaWithoutId(_):
          return "schema error"
        case .unknownSchemaResource(_):
          return "identifier error"
      }
    }
  }
  
  /// Initializes a new empty schema registry using `.draft2020` as default schema dialect.
  public convenience init(defaultDialect: JSONSchemaDialect = .draft2020) {
    self.init(defaultDialect: defaultDialect,
              dialects: [defaultDialect.uri : defaultDialect],
              resources: [:],
              providers: [])
  }
  
  /// Initializes a new empty schema registry using `.draft2020` as default schema dialect.
  fileprivate init(defaultDialect: JSONSchemaDialect,
                   dialects: [URL : JSONSchemaDialect],
                   resources: [JSONSchemaIdentifier : JSONSchemaResource],
                   providers: [JSONSchemaProvider]) {
    self.defaultDialect = defaultDialect
    self.dialects = dialects
    self.resources = resources
    self.providers = providers
  }
  
  /// Initializes a new schema registry using `.draft2020` as default schema dialect.
  /// All supported schema dialects, schema resources, and schema providers can be provided
  /// upfront.
  public init(defaultDialect: JSONSchemaDialect = .draft2020,
              dialects: [JSONSchemaDialect] = [],
              resources: [JSONSchemaResource] = [],
              providers: [JSONSchemaProvider] = []) throws {
    var dialectMap: [URL : JSONSchemaDialect] = [defaultDialect.uri : defaultDialect]
    for dialect in dialects {
      dialectMap[dialect.uri] = dialect
    }
    var resourceMap: [JSONSchemaIdentifier : JSONSchemaResource] = [:]
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
  
  /// Returns a copy of this schema registry.
  public func copy() -> JSONSchemaRegistry {
    return JSONSchemaRegistry(defaultDialect: self.defaultDialect,
                              dialects: self.dialects,
                              resources: self.resources,
                              providers: self.providers)
  }
  
  /// Registers a new schema dialect.
  @discardableResult
  public func register(dialect ds: JSONSchemaDialect...) -> JSONSchemaRegistry {
    for dialect in ds {
      self.dialects[dialect.uri] = dialect
    }
    return self
  }
  
  /// Registers a new schema resource.
  @discardableResult
  public func register(resource rs: JSONSchemaResource...) throws -> JSONSchemaRegistry {
    for resource in rs {
      guard !resource.schema.isBoolean else {
        continue
      }
      guard resource.isRoot else {
        throw Error.cannotRegisterNonRootResource(resource.schema)
      }
      self.register(resource: resource, for: resource.id)
    }
    return self
  }
  
  /// Registers a new schema resource for the given schema identifier.
  @discardableResult
  private func register(resource: JSONSchemaResource,
                        for id: JSONSchemaIdentifier?) -> JSONSchemaRegistry {
    for nested in resource.nestedResources {
      if let nestedId = nested.id, !nestedId.isEmpty {
        self.resources[nestedId] = nested
      }
    }
    if let id = id ?? resource.id, !id.isEmpty {
      self.resources[id] = resource
    }
    return self
  }
  
  /// Registers a new schema provider (as a dynamic registry extension mechanism).
  @discardableResult
  public func register(provider ps: JSONSchemaProvider...) -> JSONSchemaRegistry {
    self.providers.append(contentsOf: ps)
    return self
  }
  
  /// Loads a new schema from the given URL into the registry, using `id` as the default
  /// schema identifier (in case the schema at `url` does not define its own).
  @discardableResult
  public func loadSchema(from url: URL, id: JSONSchemaIdentifier? = nil) throws -> JSONSchemaResource {
    let resource = try JSONSchemaResource(url: url, id: id)
    try self.register(resource: resource)
    return resource
  }
  
  /// Looks up a schema resource for the given schema identifier.
  public func resource(for baseUri: JSONSchemaIdentifier) -> JSONSchemaResource? {
    // Get JSON schema resource via the first matching provider, if it is not available yet
    if self.resources[baseUri] == nil {
      for provider in self.providers {
        if let resource = provider.resource(for: baseUri) {
          self.register(resource: resource, for: baseUri)
          break
        }
      }
    }
    // Return the resource
    return self.resources[baseUri]
  }
  
  /// Entry point for a new validator for on a given JSON schema resource. `dialect` is
  /// the default dialect used if a schema resource does not define one.
  public func validator(for root: JSONSchemaResource,
                        dialect: JSONSchemaDialect? = nil) throws -> JSONSchemaValidator {
    try self.register(resource: root)
    return try JSONSchemaValidationContext(registry: self)
                 .validator(for: root, at: .root, dialect: dialect)
  }
  
  /// Entry point for a new validator for a JSON schema resource identified by `baseUri`.
  /// `dialect` is the default dialect used if a schema resource does not define one.
  public func validator(for baseUri: JSONSchemaIdentifier,
                        dialect: JSONSchemaDialect? = nil) throws -> JSONSchemaValidator {
    guard let root = self.resource(for: baseUri) else {
      throw Error.unknownSchemaResource(baseUri.string)
    }
    return try JSONSchemaValidationContext(registry: self)
                 .validator(for: root, at: .root, dialect: dialect)
  }
  
  /// Entry point for a new validator for a JSON schema resource identified by `uristring`.
  /// `dialect` is the default dialect used if a schema resource does not define one.
  public func validator(for uristring: String,
                        dialect: JSONSchemaDialect? = nil) throws -> JSONSchemaValidator {
    guard let baseUri = JSONSchemaIdentifier(string: uristring),
          let root = self.resource(for: baseUri) else {
      throw Error.unknownSchemaResource(uristring)
    }
    return try JSONSchemaValidationContext(registry: self)
                 .validator(for: root, at: .root, dialect: dialect)
  }
}

///
/// Special version of `JSONSchemaRegistry` with support to reset the resources.
///
public final class DefaultJSONSchemaRegistry: JSONSchemaRegistry {
  public init() {
    let dialect: JSONSchemaDialect = .draft2020
    super.init(defaultDialect: dialect,
               dialects: [dialect.uri : dialect],
               resources: [:],
               providers: [])
  }
  
  public func clear(defaultDialect: JSONSchemaDialect? = nil,
                    preserveProviders: Bool = true) {
    if let defaultDialect {
      self.dialects.removeAll()
      self.dialects[defaultDialect.uri] = defaultDialect
    }
    self.resources.removeAll()
    if !preserveProviders {
      self.providers.removeAll()
    }
  }
}
