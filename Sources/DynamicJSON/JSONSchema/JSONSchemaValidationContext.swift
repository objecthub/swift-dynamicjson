//
//  JSONValidationContext.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 30/03/2024.
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
  public let location: JSONLocation
  public let active: [JSONSchemaResource]
  
  public init(registry: JSONSchemaRegistry, resource: JSONSchemaResource? = nil) {
    self.init(registry: registry, location: .root, active: resource == nil ? [] : [resource!])
  }
  
  public init(registry: JSONSchemaRegistry, location: JSONLocation, active: [JSONSchemaResource]) {
    self.registry = registry
    self.location = location
    self.active = active
  }
  
  public var resource: JSONSchemaResource? {
    return self.active.last
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
    let id = resource?.uri(relative: uri) ?? uri
    let baseUri = id.baseIdentifier
    let fragment = id.fragment
    // Determine base
    var base = self.resource
    if base == nil || !baseUri.lastPathComponent.isEmpty {
      base = self.registry.resource(for: baseUri)
    }
    // Resolve fragment
    if let resource = base {
      // Return validator for the resolved schema resource
      switch try resource.resolve(fragment: fragment) {
        case .static(let target):
          return try self.validator(for: target, at: location, dialect: dialect)
        case .dynamic(let target):
          // print("@@@ resolving \(fragment) to \(target)")
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
      // print(" try finding '\(fragment)' in \(resource) | \(resource.dynamicSelfAnchor)")
      if resource.dynamicSelfAnchor == fragment {
        // print("--- dynamic resolution found \(resource)")
        return resource
      } else if let anchors = resource.anchors,
         case .some(.dynamic(let target)) = anchors[fragment] {
        // print("~~~ dynamic resolution found \(target)")
        return target
      }
    }
    return nil
  }
  
  /// Return validator for `schema` at `location` (relative to the root JSON schema) within
  /// the context of JSON schema resource `base`. `dialect` is the default schema dialect
  /// to be used.
  public func validator(for base: JSONSchemaResource,
                        at location: JSONLocation = .root,
                        dialect: JSONSchemaDialect? = nil) throws -> JSONSchemaValidator {
    guard location.segmentCount < 100 else {
      throw Error.validationDepthExhausted(location)
    }
    let schema = base.schema
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
  /// the context of JSON schema resource `base`. `dialect` is the default schema dialect
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
      let global = resource?.uri(relative: id) ?? id
      let baseUri = global.baseIdentifier
      let fragment = global.fragment
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
