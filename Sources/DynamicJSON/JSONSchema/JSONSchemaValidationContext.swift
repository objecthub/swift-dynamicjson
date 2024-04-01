//
//  JSONValidationContext.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 30/03/2024.
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

public struct JSONSchemaValidationContext {
  
  /// Collection of errors raised by functionality provided by `JSONSchemaRegistry`.
  public enum Error: LocalizedError, CustomStringConvertible {
    case unknownDialect(URL)
    case unknownResource(JSONSchemaIdentifier)
    case validationDepthExhausted(JSONLocation)
    
    public var description: String {
      switch self {
        case .unknownDialect(let uri):
          return "unsupported dialect \(uri)"
        case .unknownResource(let uri):
          return "unknown JSON schema resource \(uri)"
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
        case .unknownResource(_):
          return "schema error"
        case .validationDepthExhausted(_):
          return "validation error"
      }
    }
  }
  
  public let registry: JSONSchemaRegistry
  public let path: [JSONLocation]
  public let active: [JSONSchemaResource]
  
  public init(registry: JSONSchemaRegistry, resource: JSONSchemaResource? = nil) {
    self.init(registry: registry,
              location: .root,
              path: [],
              active: resource == nil ? [] : [resource!])
  }
  
  private init(registry: JSONSchemaRegistry,
              location: JSONLocation,
              path: [JSONLocation],
              active: [JSONSchemaResource]) {
    var path = path
    path.append(location)
    self.registry = registry
    self.path = path
    self.active = active
  }
  
  public var isDelegated: Bool {
    return self.path.count > 1 && self.path[self.path.count - 1] == self.path[self.path.count - 2]
  }
  
  public var resource: JSONSchemaResource? {
    return self.active.last
  }
  
  public var location: JSONLocation {
    return self.path.last!
  }
  
  public func memberLocation(_ member: String) -> JSONLocation {
    return .member(self.location, member)
  }
  
  public func context(for resource: JSONSchemaResource,
                      at location: JSONLocation) -> JSONSchemaValidationContext {
    var extended = self.active
    extended.append(resource)
    return JSONSchemaValidationContext(registry: self.registry,
                                       location: location,
                                       path: self.path,
                                       active: extended)
  }
  
  /// Return validator for a schema referenced by `uri` in the context of JSON schema
  /// resource `base` at `location` (relative to the root JSON schema). `dialect` is the
  /// default schema dialect to be used.
  public func validator(for uri: JSONSchemaIdentifier,
                        at location: JSONLocation = .root,
                        dynamic: Bool = false,
                        dialect: JSONSchemaDialect? = nil) throws -> JSONSchemaValidator {
    // Determine base URI and fragment
    let id = uri.relative(to: self.resource?.id)
    let baseUri = id.baseIdentifier
    let fragment = id.fragment
    // Determine base resource and resolve fragment
    if let resource = self.registry.resource(for: baseUri) ?? self.resource {
      // Return validator for the resolved schema resource
      switch try resource.resolve(fragment: fragment) {
        case .static(let target):
          return try self.validator(for: target, at: location, dialect: dialect)
        case .dynamic(let target):
          if dynamic {
            return try self.validator(for: self.dynamicResolve(fragment: fragment) ?? target,
                                      at: location,
                                      dialect: dialect)
          } else {
            return try self.validator(for: target, at: location, dialect: dialect)
          }
      }
    } else {
      throw Error.unknownResource(id)
    }
  }
  
  private func dynamicResolve(fragment: String?) -> JSONSchemaResource? {
    guard let fragment else {
      return nil
    }
    for resource in self.active {
      if resource.dynamicSelfAnchor == fragment {
        return resource
      } else if let anchors = resource.anchors,
         case .some(.dynamic(let target)) = anchors[fragment] {
        return target
      }
    }
    return nil
  }
  
  /// Return validator for `schema` at `location` (relative to the root JSON schema) within
  /// the context of JSON schema resource `base`. `dialect` is the default schema dialect
  /// to be used.
  public func validator(for resource: JSONSchemaResource,
                        at location: JSONLocation = .root,
                        dialect: JSONSchemaDialect? = nil) throws -> JSONSchemaValidator {
    return try self.validator(for: resource.schema,
                              at: location,
                              base: resource.nonAnonymousResource,
                              dialect: dialect)
  }
  
  /// Return validator for `schema` at `location` (relative to the root JSON schema) within
  /// the context of JSON schema resource `base`. `dialect` is the default schema dialect
  /// to be used.
  public func validator(for schema: JSONSchema,
                        at location: JSONLocation = .root,
                        base: JSONSchemaResource,
                        dialect: JSONSchemaDialect? = nil) throws -> JSONSchemaValidator {
    guard location.segmentCount < 100 else {
      throw Error.validationDepthExhausted(location)
    }
    if let dialect, schema.schema == nil {
      return dialect.validator(for: schema, in: self.context(for: base, at: location))
    } else {
      let dialectUri = schema.schema ?? self.registry.defaultDialect.uri
      guard let dialect = self.registry.dialects[dialectUri] else {
        throw Error.unknownDialect(dialectUri)
      }
      return dialect.validator(for: schema, in: self.context(for: base, at: location))
    }
  }
  
  /// Return validator for `schema` at `location` (relative to the root JSON schema) within
  /// the context of the current JSON schema resource. `dialect` is the default schema dialect
  /// to be used.
  public func validator(for schema: JSONSchema,
                        at location: JSONLocation = .root,
                        dialect: JSONSchemaDialect? = nil) throws -> JSONSchemaValidator {
    guard location.segmentCount < 100 else {
      throw Error.validationDepthExhausted(location)
    }
    var base = self.resource
    // Determine a potentially new base schema resource
    if let id = schema.id {
      // Determine base URI and fragment
      let global = id.relative(to: resource?.id)
      let baseUri = global.baseIdentifier
      // let fragment = global.fragment
      // TODO: Flag if fragment is not nil?
      base = self.registry.resource(for: baseUri) ?? base
    }
    if let dialect, schema.schema == nil {
      return dialect.validator(for: schema,
                               in: self.context(for: base ?? JSONSchemaResource(nested: schema),
                                                at: location))
    } else {
      let dialectUri = schema.schema ?? self.registry.defaultDialect.uri
      guard let dialect = self.registry.dialects[dialectUri] else {
        throw Error.unknownDialect(dialectUri)
      }
      return dialect.validator(for: schema,
                               in: self.context(for: base ?? JSONSchemaResource(nested: schema),
                                                at: location))
    }
  }
}
