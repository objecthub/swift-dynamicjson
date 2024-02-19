//
//  JSON.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 11/02/2024.
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

@dynamicMemberLookup
public enum JSON: Hashable,
                  Equatable,
                  Codable,
                  CustomStringConvertible,
                  CustomDebugStringConvertible,
                  ExpressibleByNilLiteral,
                  ExpressibleByBooleanLiteral,
                  ExpressibleByIntegerLiteral,
                  ExpressibleByFloatLiteral,
                  ExpressibleByStringLiteral,
                  ExpressibleByArrayLiteral,
                  ExpressibleByDictionaryLiteral {
  case null
  case boolean(Bool)
  case integer(Int64)
  case float(Double)
  case string(String)
  case array([JSON])
  case object([String : JSON])
  
  public init(nilLiteral: ()) {
    self = .null
  }
  
  public init(booleanLiteral value: Bool) {
    self = .boolean(value)
  }
  
  public init(integerLiteral value: Int64) {
    self = .integer(value)
  }
  
  public init(floatLiteral value: Double) {
    self = .float(value)
  }
  
  public init(stringLiteral value: String) {
    self = .string(value)
  }
  
  public init(arrayLiteral elements: JSON...) {
    self = .array(elements)
  }
  
  public init(dictionaryLiteral elements: (String, JSON)...) {
    var object: [String:JSON] = [:]
    for (k, v) in elements {
      object[k] = v
    }
    self = .object(object)
  }
  
  public init(_ value: Any) throws {
    switch value {
      case _ as NSNull:
        self = .null
      case let opt as Optional<Any> where opt == nil:
        self = .null
      case let bool as Bool:
        self = .boolean(bool)
      case let num as Int:
        self = .integer(Int64(num))
      case let num as Int64:
        self = .integer(num)
      case let num as Double:
        self = .float(num)
      case let num as NSNumber:
        if num.isBool {
          self = .boolean(num.boolValue)
        } else if let value = num as? Int {
          self = .integer(Int64(value))
        } else if let value = num as? Int64 {
          self = .integer(value)
        } else if let value = num as? Double {
          self = .float(value)
        } else {
          throw JSONError.initialization
        }
      case let str as String:
        self = .string(str)
      case let array as [Any]:
        self = .array(try array.map(JSON.init))
      case let dict as [String : Any]:
        self = .object(try dict.mapValues(JSON.init))
      case let obj as Encodable:
        self = try .init(encodable: obj)
      default:
        throw JSONError.initialization
    }
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let object = try? container.decode([String: JSON].self) {
      self = .object(object)
    } else if let array = try? container.decode([JSON].self) {
      self = .array(array)
    } else if let string = try? container.decode(String.self) {
      self = .string(string)
    } else if let bool = try? container.decode(Bool.self) {
      self = .boolean(bool)
    } else if let number = try? container.decode(Int64.self) {
      self = .integer(number)
    } else if let number = try? container.decode(Double.self) {
      self = .float(number)
    } else if container.decodeNil() {
      self = .null
    } else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: decoder.codingPath,
                              debugDescription: "Invalid JSON value"))
    }
  }
  
  public init(encodable: Encodable) throws {
    self = try JSONDecoder().decode(JSON.self, from: try JSONEncoder().encode(encodable))
  }
  
  public init(encoded: Data,
              dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
              floatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw,
              userInfo: [CodingUserInfoKey : Any]? = nil) throws {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .useDefaultKeys
    decoder.dateDecodingStrategy = dateDecodingStrategy
    decoder.nonConformingFloatDecodingStrategy = floatDecodingStrategy
    if let userInfo {
      decoder.userInfo = userInfo
    }
    self = try JSONDecoder().decode(JSON.self, from: encoded)
  }
  
  public init(encoded: String,
              dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
              floatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw,
              userInfo: [CodingUserInfoKey : Any]? = nil) throws {
    guard let data = encoded.data(using: .utf8) else {
      throw JSONError.erroneousEncoding
    }
    self = try .init(encoded: data,
                     dateDecodingStrategy: dateDecodingStrategy,
                     floatDecodingStrategy: floatDecodingStrategy,
                     userInfo: userInfo)
  }
  
  public func data(formatting: JSONEncoder.OutputFormatting = .init(),
                   dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
                   floatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy = .throw,
                   userInfo: [CodingUserInfoKey : Any]? = nil) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = formatting
    encoder.keyEncodingStrategy = .useDefaultKeys
    encoder.dateEncodingStrategy = dateEncodingStrategy
    encoder.nonConformingFloatEncodingStrategy = floatEncodingStrategy
    if let userInfo {
      encoder.userInfo = userInfo
    }
    return try encoder.encode(self)
  }
  
  public func string(formatting: JSONEncoder.OutputFormatting = .init(),
                     dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
                     floatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy = .throw,
                     userInfo: [CodingUserInfoKey : Any]? = nil) throws -> String? {
    return String(data: try self.data(formatting: formatting,
                                      dateEncodingStrategy: dateEncodingStrategy,
                                      floatEncodingStrategy: floatEncodingStrategy,
                                      userInfo: userInfo),
                  encoding: .utf8)
  }
  
  public func coerce<T: Decodable>() throws -> T {
    return try JSONDecoder().decode(T.self, from: try JSONEncoder().encode(self))
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
      case .null:
        try container.encodeNil()
      case .boolean(let bool):
        try container.encode(bool)
      case .integer(let number):
        try container.encode(number)
      case .float(let number):
        try container.encode(number)
      case .string(let string):
        try container.encode(string)
      case .array(let array):
        try container.encode(array)
      case .object(let object):
        try container.encode(object)
    }
  }
  
  public var isNull: Bool {
    guard case .null = self else {
      return false
    }
    return true
  }
  
  public var boolValue: Bool? {
    guard case .boolean(let value) = self else {
      return nil
    }
    return value
  }
  
  public var intValue: Int? {
    guard case .integer(let value) = self,
          let res = Int(exactly: value) else {
      return nil
    }
    return res
  }
  
  public var int64Value: Int64? {
    guard case .integer(let value) = self else {
      return nil
    }
    return value
  }
  
  public var doubleValue: Double? {
    switch self {
      case .integer(let num):
        return Double(num)
      case .float(let num):
        return num
      default:
        return nil
    }
  }

  public var stringValue: String? {
    guard case .string(let value) = self else {
      return nil
    }
    return value
  }
  
  public var arrayValue: [JSON]? {
    guard case .array(let value) = self else {
      return nil
    }
    return value
  }
  
  public var objectValue: [String: JSON]? {
    guard case .object(let value) = self else {
      return nil
    }
    return value
  }
  
  public var children: [JSON] {
    switch self {
      case .null, .boolean(_), .integer(_), .float(_), .string(_):
        return []
      case .array(let arr):
        return arr
      case .object(let dict):
        return [JSON](dict.values)
    }
  }
  
  public func forEachDescendant(_ proc: (JSON) throws -> Void) rethrows {
    try proc(self)
    for child in self.children {
      try child.forEachDescendant(proc)
    }
  }
  
  public subscript(index: Int) -> JSON? {
    guard case .array(let array) = self, array.indices.contains(index) else {
      return nil
    }
    return array[index]
  }
  
  public subscript(key: String) -> JSON? {
    guard case .object(let dict) = self else {
      return nil
    }
    return dict[key]
  }
  
  public subscript(dynamicMember key: String) -> JSON? {
    return self[key]
  }
  
  public subscript(keyPath location: JSONLocation) -> JSON? {
    return location.apply(to: self)
  }
  
  public subscript(keyPath location: String) -> JSON? {
    get throws {
      let trimmed = location.trimmingCharacters(in: CharacterSet.whitespaces)
      if trimmed.first == "." {
        return try JSONLocation("$" + trimmed).apply(to: self)
      } else if trimmed.first == "$" {
        return try JSONLocation(trimmed).apply(to: self)
      } else {
        return try JSONLocation("$." + trimmed).apply(to: self)
      }
    }
  }
  
  public func merging(with other: JSON) -> JSON {
    if case .object(let lhs) = self,
       case .object(let rhs) = other {
      var res: [String : JSON] = [:]
      for (key, lhsval) in lhs {
        if let rhsval = rhs[key] {
          res[key] = lhsval.merging(with: rhsval)
        } else {
          res[key] = lhsval
        }
      }
      for (key, rhsval) in rhs where lhs[key] == nil {
        res[key] = rhsval
      }
      return .object(res)
    } else {
      return other
    }
  }
  
  public func updating(_ location: JSONLocation, with json: JSON) throws -> JSON {
    return try self.updating(location.segments, 0, with: json)
  }
  
  private func updating(_ segments: [JSONLocation.Segment],
                        _ current: Int,
                        with json: JSON) throws -> JSON {
    if current < segments.count {
      switch segments[current] {
        case .index(let index):
          guard case .array(var array) = self, array.indices.contains(index) else {
            throw JSONError.erroneousIndexSelection(self, index)
          }
          array[index] = try array[index].updating(segments, current + 1, with: json)
          return .array(array)
        case .member(let key):
          guard case .object(var dict) = self, let rhsval = dict[key] else {
            throw JSONError.erroneousKeySelection(self, key)
          }
          dict[key] = try rhsval.updating(segments, current + 1, with: json)
          return .object(dict)
      }
    } else {
      return json
    }
  }
  
  public var description: String {
    return (try? self.string(
             formatting: [.prettyPrinted, .sortedKeys],
             dateEncodingStrategy: .iso8601,
             floatEncodingStrategy: .convertToString(positiveInfinity: "Infinity",
                                                     negativeInfinity: "-Infinity",
                                                     nan: "NaN"))) ?? "<invalid JSON>"
  }
  
  public var debugDescription: String {
    switch self {
      case .null:
        return "null"
      case .boolean(let bool):
        return bool.description
      case .integer(let number):
        return number.description
      case .float(let number):
        return number.debugDescription
      case .string(let str):
        return str.debugDescription
      default:
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let res = try? String(data: encoder.encode(self), encoding: .utf8) {
          return res
        } else {
          return "<error>"
        }
    }
  }
}
