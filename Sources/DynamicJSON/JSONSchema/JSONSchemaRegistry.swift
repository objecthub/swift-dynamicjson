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
  public static let `default` = JSONSchemaRegistry()
  
  /// The default dialect used by this registry
  public let defaultDialect: JSONSchemaDialect
  
  /// Maps meta-schema URIs (i.e. $schema) to dialects
  public private(set) var dialects: [URL : JSONSchemaDialect]
  
  /// Maps schema identifiers (i.e. $id) to schema
  public private(set) var resources: [JSONSchemaIdentifier : JSONSchemaResource]
  
  /// Dynamic extension modules providing new JSON schema resources
  private var providers: [JSONSchemaProvider]
  
  /// Collection of errors raised by functionality provided by `JSONSchemaRegistry`.
  public enum Error: LocalizedError, CustomStringConvertible {
    case cannotRegisterNonRootResource(JSONSchema)
    case schemaWithoutId(JSONSchema)
    
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
      }
    }
    
    public var errorDescription: String? {
      return self.description
    }
    
    public var failureReason: String? {
      switch self {
        case .cannotRegisterNonRootResource(_), .schemaWithoutId(_):
          return "schema error"
      }
    }
  }
  
  /// Initializes a new empty schema registry using `.draft2020` as default schema dialect.
  public init(defaultDialect: JSONSchemaDialect = .draft2020) {
    self.defaultDialect = defaultDialect
    self.dialects = [defaultDialect.uri : defaultDialect]
    self.resources = [:]
    self.providers = []
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
  
  /// Registers a new schema dialect.
  public func register(dialect: JSONSchemaDialect) {
    self.dialects[dialect.uri] = dialect
  }
  
  /// Registers a new schema resource.
  public func register(resource: JSONSchemaResource) throws {
    guard !resource.schema.isBoolean else {
      return
    }
    guard resource.isRoot else {
      throw Error.cannotRegisterNonRootResource(resource.schema)
    }
    self.register(resource: resource, for: resource.id)
  }
  
  /// Registers a new schema resource for the given schema identifier.
  private func register(resource: JSONSchemaResource, for id: JSONSchemaIdentifier?) {
    for nested in resource.nestedResources {
      if let nestedId = nested.id, !nestedId.isEmpty {
        self.resources[nestedId] = nested
      }
    }
    if let id = id ?? resource.id, !id.isEmpty {
      self.resources[id] = resource
    }
  }
  
  /// Registers a new schema provider (as a dynamic registry extension mechanism).
  public func register(provider: JSONSchemaProvider) {
    self.providers.append(provider)
  }
  
  /// Loads a new schema from the given URL into the registry, using `id` as the default
  /// schema identifier (in case the schema at `url` does not define its own).
  @discardableResult
  public func loadSchema(from url: URL, id: JSONSchemaIdentifier?) throws -> JSONSchemaResource {
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
}
