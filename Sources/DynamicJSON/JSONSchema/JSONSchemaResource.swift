//
//  JSONSchemaResource.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 25/03/2024.
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
/// Implementation of JSON Schema resources. These are containers for managing JSON schema.
/// Each resource encapsulates one schema. It manages various indices to look up nested schema
/// as well as anchor definitions. Since schema might be nested, each schema also has an
/// optional `outer` link to its enclosing schema.
///
public class JSONSchemaResource: CustomStringConvertible, CustomDebugStringConvertible {
  public let schema: JSONSchema
  private var distance: Int = .max
  public private(set) weak var outer: JSONSchemaResource? = nil
  public private(set) var nested: [JSONLocation : JSONSchemaResource]?
  public private(set) var anchors: [String : Anchor]?
  public private(set) var selfAnchor: String? = nil
  public private(set) var dynamicSelfAnchor: String? = nil
  
  /// Anchors are either static and dynamic. They are stored in resolved form, i.e.
  /// referring directly to the corresponding `JSONSchemaResource` object.
  public enum Anchor {
    case `static`(JSONSchemaResource)
    case `dynamic`(JSONSchemaResource)
    
    var isStatic: Bool {
      switch self {
        case .static(_):
          return true
        case .dynamic(_):
          return false
      }
    }
    
    var resource: JSONSchemaResource {
      switch self {
        case .static(let resource):
          return resource
        case .dynamic(let resource):
          return resource
      }
    }
  }
  
  /// Collection of errors raised by functionality provided by `JSONSchemaResource`.
  public enum Error: LocalizedError, CustomStringConvertible {
    case cannotDecodeString
    case rootSchemaRequiresAbsoluteId
    case schemaWithoutId(JSONSchema)
    case illegalUriFragment(String)
    
    public var description: String {
      switch self {
        case .cannotDecodeString:
          return "cannot decode string into a JSON schema"
        case .rootSchemaRequiresAbsoluteId:
          return "root schema objects require absolute URI as $id"
        case .schemaWithoutId(let schema):
          if let title = schema.title {
            return "schema \"\(title)\" does not provide an $id"
          } else {
            return "schema does not provide an $id"
          }
        case .illegalUriFragment(let fragment):
          return "illegal URI fragment '\(fragment)'"
      }
    }
    
    public var errorDescription: String? {
      return self.description
    }
    
    public var failureReason: String? {
      switch self {
        case .cannotDecodeString:
          return "decoding error"
        case .rootSchemaRequiresAbsoluteId, .schemaWithoutId(_):
          return "schema error"
        case .illegalUriFragment(_):
          return "URI error"
      }
    }
  }
  
  /// Used to initialize nested schema resources.
  internal init(nested: JSONSchema, outer: JSONSchemaResource? = nil) {
    self.schema = nested
    if nested.isBoolean {
      self.nested = nil
      self.anchors = nil
    } else {
      self.nested = [:]
      self.anchors = [:]
    }
    self.outer = outer
  }
  
  /// Initializes root schema resources, scans the whole document and sets up lookup
  /// tables for nested schema and anchors. This constructor forces schema `root` to have
  /// an id, i.e. it will generate one if not available.
  public convenience init(root: JSONSchema) throws {
    switch root {
      case .boolean(_):
        self.init(nested: root)
        return
      case .descriptor(var descriptor, let json):
        if descriptor.id == nil {
          descriptor.id = JSONSchemaIdentifier(string: UUID().uuidString)
        }
        self.init(nested: .descriptor(descriptor, json))
    }
    let schemaObjects = self.schema.schemaObjects
    for (location, schema) in schemaObjects where location != .root {
      let resource = JSONSchemaResource(nested: schema)
      for (nestedloc, nestedsub) in self.nested! {
        if let relativeloc = location.relative(to: nestedloc) {
          nestedsub.nest(resource, at: relativeloc)
        } else if let relativeloc = nestedloc.relative(to: location) {
          resource.nest(nestedsub, at: relativeloc)
        }
      }
      self.nested![location] = resource
    }
    for resource in self.nested!.values {
      if resource.outer == nil {
        resource.outer = self
      }
      if case .descriptor(let descriptor, _) = resource.schema {
        if let anchor = descriptor.anchor {
          if descriptor.id != nil {
            resource.selfAnchor = anchor
          } else if let outer = resource.outer, !outer.schema.isBoolean {
            outer.anchors![anchor] = .static(resource)
          }
        }
        if let anchor = descriptor.dynamicAnchor {
          if descriptor.id != nil {
            resource.dynamicSelfAnchor = anchor
          } else if let outer = resource.outer, !outer.schema.isBoolean {
            outer.anchors![anchor] = .dynamic(resource)
          }
        }
      }
    }
    if case .descriptor(let descriptor, _) = self.schema, descriptor.id != nil {
      if let anchor = descriptor.anchor {
        self.selfAnchor = anchor
      }
      if let anchor = descriptor.dynamicAnchor {
        self.dynamicSelfAnchor = anchor
      }
    }
  }
  
  public convenience init(data: Data, id: JSONSchemaIdentifier? = nil) throws {
    let schema = try JSONDecoder().decode(JSONSchema.self, from: data)
    switch schema {
      case .boolean(_):
        try self.init(root: schema)
      case .descriptor(var descriptor, let json):
        if descriptor.id == nil {
          descriptor.id = id
        }
        try self.init(root: .descriptor(descriptor, json))
    }
  }
  
  /// Initializes a schema resource from a string representation. The given schema
  /// identifier `id` is only used if the schema does not define one itself.
  public convenience init(string: String, id: JSONSchemaIdentifier? = nil) throws {
    guard let data = string.data(using: .utf8) else {
      throw Error.cannotDecodeString
    }
    try self.init(data: data, id: id)
  }
  
  /// Initializes a schema resource from a URL for the given default JSON schema identifier.
  /// The given schema identifier `id` is only used if the schema does not define one itself.
  public convenience init(url: URL, id: JSONSchemaIdentifier? = nil) throws {
    try self.init(data: try Data(contentsOf: url), id: id)
  }
  
  /// Returns true if this is an anonymous schema resource
  public var isAnonymous: Bool {
    return self.schema.id == nil
  }
  
  /// Returns true if this is a root schema resource, i.e. it does not have an outer resource.
  public var isRoot: Bool {
    return self.schema.id != nil && self.outer == nil
  }
  
  /// Returns the id of this schema resource
  public var id: JSONSchemaIdentifier? {
    return self.schema.id
  }
  
  public var nonAnonymousResource: JSONSchemaResource {
    var res: JSONSchemaResource? = self
    while res?.isAnonymous ?? false {
      res = res?.outer
    }
    return res ?? self
  }
  
  /// Returns a resource map for all internal, nested schema resources.
  public var resources: [JSONSchemaIdentifier : JSONSchemaResource] {
    guard let nested else {
      return [:]
    }
    var res: [JSONSchemaIdentifier : JSONSchemaResource] = [:]
    for nested in nested.values {
      if let nestedId = nested.id {
        res[nestedId] = nested
      }
    }
    if let id {
      res[id] = self
    }
    return res
  }
  
  /// Returns all nested schema resources.
  public var nestedResources: [JSONSchemaResource] {
    return [JSONSchemaResource]((self.nested ?? [:]).values)
  }
  
  /// Resolves a fragment relative to this schema resource.
  public func resolve(fragment: String?) throws -> Anchor {
    if self.isAnonymous, let outer = self.outer {
      return try outer.resolve(fragment: fragment)
    }
    guard let fragment else {
      return .static(self)
    }
    if fragment.isEmpty {
      return .static(self)
    } else if fragment.starts(with: "/") {
      if let nested = self.nested {
        // Resolve as JSON pointer reference
        let pointer = try JSONPointer(fragment)
        let locations = pointer.locations()
        // Find via known keywords
        for location in locations {
          if let subschema = nested[location] {
            return .static(subschema)
          }
        }
        // Find via unknown keywords
        if case .descriptor(_, let json) = self.schema,
           let target = pointer.get(from: json),
           let targetSchema: JSONSchema = try? target.coerce() {
          return .static(JSONSchemaResource(nested: targetSchema, outer: self))
        }
      }
    } else if let anchors = self.anchors, let subschema = anchors[fragment] {
      return subschema
    } else if self.selfAnchor == fragment {
      return .static(self)
    } else if self.dynamicSelfAnchor == fragment {
      return .dynamic(self)
    }
    throw Error.illegalUriFragment(fragment)
  }
  
  /// Nests a subschema under this schema at `location`.
  private func nest(_ subschema: JSONSchemaResource, at location: JSONLocation) {
    guard !self.isAnonymous else {
      return
    }
    self.nested?[location] = subschema
    let distance = location.segmentCount
    if !self.isAnonymous && distance < subschema.distance {
      subschema.outer = self
      subschema.distance = distance
    }
  }
  
  public var description: String {
    if let id = self.id {
      return "resource(\(id))"
    } else {
      return "resource(<anon>)"
    }
  }
  
  public var debugDescription: String {
    var res: String = "JSON SCHEMA RESOURCE FOR\n" + self.schema.debugDescription + "\n"
    if let outer = self.outer {
      res += "OUTER (distance = \(self.distance)\n" + outer.schema.debugDescription + "\n"
    }
    if let nested = self.nested {
      res += "NESTED\n"
      for (key, value) in nested {
        res += "  \(key) -> \(value.description)\n"
      }
    }
    if let anchors = self.anchors {
      res += "ANCHORS\n"
      for (key, value) in anchors {
        if value.isStatic {
          res += "  static \(key) -> \(value.resource.description)\n"
        } else {
          res += "  dynamic \(key) -> \(value.resource.description)\n"
        }
      }
    }
    if let selfAnchor = self.selfAnchor {
      res += "SELF ANCHOR = '\(selfAnchor)'\n"
    }
    if let selfAnchor = self.dynamicSelfAnchor {
      res += "DYNAMIC SELF ANCHOR = '\(selfAnchor)'\n"
    }
    return res
  }
}
