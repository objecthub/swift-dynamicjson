//
//  JSONType.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 19/02/2024.
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
/// Representation of types for JSON values. The struct supports both individual
/// types as well as type sets. The supported basic types are:
///
///   - `null`
///   - `boolean`
///   - `number` (representing both integers and floats)
///   - `string`
///   - `array`
///   - `object`
///
public struct JSONType: OptionSet,
                        Hashable,
                        Codable,
                        Sendable,
                        CustomStringConvertible,
                        CustomDebugStringConvertible {
  
  /// The raw value of this type/type set.
  public let rawValue: UInt
  
  /// The name of a basic type. Type sets do not have a name.
  public let name: String?
  
  /// Initialize a new JSON type set.
  public init(rawValue: UInt) {
    self.rawValue = rawValue
    self.name = nil
  }
  
  /// Initialize a new basic JSON type with the given name.
  public init(rawValue: UInt, name: String) {
    self.rawValue = rawValue
    self.name = name
  }
  
  /// Decode the JSON type via the given decoder.
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let names = try? container.decode([String].self) {
      var res: JSONType = []
      for name in names {
        if let type = JSONType.simpleType(name) {
          res = res.union(type)
        } else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath,
                                  debugDescription: "Unknown JSONType specifier"))
        }
      }
      self = res
    } else if let name = try? container.decode(String.self),
              let type = JSONType.simpleType(name) {
      self = type
    } else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: decoder.codingPath,
                              debugDescription: "Invalid JSONType specifier"))
    }
  }
  
  /// Encode this JSON type using the given encoder.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
      case .null, .boolean, .number, .string, .array, .object:
        try container.encode(self.description)
      default:
        var names: [String] = []
        for type in JSONType.types {
          if self.contains(type) {
            names.append(type.description)
          }
        }
        try container.encode(names)
    }
  }
  
  /// The JSON null type.
  public static let null = JSONType(rawValue: 1 << 0, name: "null")
  
  /// The JSON boolean type.
  public static let boolean = JSONType(rawValue: 1 << 1, name: "boolean")
  
  /// The JSON number type, covering both integers and floating-point numbers.
  public static let number = JSONType(rawValue: 1 << 2, name: "number")
  
  /// The JSON number type, covering integer numbers.
  public static let integer = JSONType(rawValue: 1 << 3, name: "integer")
  
  /// The JSON string type.
  public static let string = JSONType(rawValue: 1 << 4, name: "string")
  
  /// The JSON array type, representing sequences of JSON values.
  public static let array = JSONType(rawValue: 1 << 5, name: "array")
  
  /// The JSON object type, representing dictionaries/name-value pairs.
  public static let object = JSONType(rawValue: 1 << 6, name: "object")
  
  /// A JSON type set including all JSON types.
  public static let all: JSONType = [.null, .boolean, .number, .integer, .string, .array, .object]
  
  /// Internal array of basic JSON types.
  private static let types: [JSONType] = [.null, .boolean, .number, .integer, .string, .array, .object]
  
  /// Returns a textual description of this type/type set.
  public var description: String {
    var res = [String]()
    for type in JSONType.types {
      if self.contains(type), let name = type.name {
        res.append(name)
      }
    }
    switch res.count {
      case 0:
        return "none"
      case 1:
        return res[0]
      case 2:
        return "\(res[0]) or \(res[1])"
      default:
        return "\(res.dropLast().joined(separator: ", ")) or \(res.last!)"
    }
  }
  
  /// Returns a textual description of this type/type set for debugging purposes.
  public var debugDescription: String {
    var res = [String]()
    for type in JSONType.types {
      if self.contains(type), let name = type.name {
        res.append(name)
      }
    }
    return res.debugDescription
  }
  
  public func included(in expected: JSONType) -> Bool {
    var expanded = expected
    if expected.contains(.number) {
      expanded.insert(.integer)
    }
    return expanded.contains(self)
  }
  
  private static func simpleType(_ name: String) -> JSONType? {
    for type in JSONType.types {
      if type.name == name {
        return type
      }
    }
    return nil
  }
  
  public static func == (lhs: JSONType, rhs: JSONType) -> Bool {
    return lhs.rawValue == rhs.rawValue
  }
  
  public func hash(into hasher: inout Hasher) {
    return hasher.combine(self.rawValue)
  }
}
