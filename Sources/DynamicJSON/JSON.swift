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
  
  public enum Error: LocalizedError, CustomStringConvertible {
    case initialization
    case erroneousEncoding
    case cannotAppend(JSON, JSON)
    case cannotInsert(JSON, JSON, Int)
    case cannotAssign(String, JSON)
    case typeMismatch(JSONTypes, JSON)
    
    public var description: String {
      switch self {
        case .initialization:
          return "unable to initialize JSON data structure"
        case .erroneousEncoding:
          return "erroneous JSON encoding"
        case .cannotAppend(let json, let array):
          return "unable to append \(json) to \(array)"
        case .cannotInsert(let json, let array, let index):
          return "unable to insert \(json) into \(array) at \(index)"
        case .cannotAssign(let member, let json):
          return "unable to set/update member '\(member)' of \(json)"
        case .typeMismatch(let types, let json):
          return "expected \(json) to be of type \(types)"
      }
    }
    
    public var errorDescription: String? {
      return self.description
    }
    
    public var failureReason: String? {
      switch self {
        case .initialization:
          return "initialization error"
        case .erroneousEncoding:
          return "encoding error"
        case .cannotAppend(_, _), .cannotInsert(_, _, _), .cannotAssign(_, _):
          return "mutation error"
        case .typeMismatch(_, _):
          return "type mismatch"
      }
    }
  }
  
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
          throw Error.initialization
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
        throw Error.initialization
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
    self = try decoder.decode(JSON.self, from: encoded)
  }
  
  public init(encoded: String,
              dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
              floatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw,
              userInfo: [CodingUserInfoKey : Any]? = nil) throws {
    guard let data = encoded.data(using: .utf8) else {
      throw Error.erroneousEncoding
    }
    self = try .init(encoded: data,
                     dateDecodingStrategy: dateDecodingStrategy,
                     floatDecodingStrategy: floatDecodingStrategy,
                     userInfo: userInfo)
  }
  
  public var type: JSONTypes {
    switch self {
      case .null:
        return .null
      case .boolean(_):
        return .boolean
      case .integer(_):
        return .number
      case .float(_):
        return .number
      case .string(_):
        return .string
      case .array(_):
        return .array
      case .object(_):
        return .object
    }
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
  
  public subscript(member: String) -> JSON? {
    guard case .object(let dict) = self else {
      return nil
    }
    return dict[member]
  }
  
  public subscript(dynamicMember member: String) -> JSON? {
    return self[member]
  }
  
  public subscript(keyPath ref: JSONReference) -> JSON? {
    return ref.get(from: self)
  }
  
  public subscript(keyPath reference: String) -> JSON? {
    get throws {
      return try JSON.reference(from: reference).get(from: self)
    }
  }
  
  public func query(_ path: JSONPath) throws -> [JSON] {
    return try JSONPathEvaluator(value: self).query(path)
  }
  
  public func query(_ path: String) throws -> [JSON] {
    var parser = JSONPathParser(string: path)
    return try self.query(parser.parse())
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
  
  public func updating(_ ref: JSONReference, with json: JSON) throws -> JSON {
    return try ref.set(to: json, in: self)
  }
  
  public func updating(_ ref: String, with json: JSON) throws -> JSON {
    return try JSON.reference(from: ref).set(to: json, in: self)
  }
  
  public mutating func append(_ json: JSON) throws {
    if case .array(var arr) = self {
      self = .null        // remove reference to arr
      arr.append(json)    // modify arr
      self = .array(arr)  // restore self
    } else if case .string(var str) = self,
              case .string(let ext) = json {
      self = .null        // remove reference to str
      str.append(ext)     // modify arr
      self = .string(str) // restore self
    } else {
      throw Error.cannotAppend(json, self)
    }
  }
  
  public mutating func insert(_ json: JSON, at index: Int) throws {
    if case .array(var arr) = self {
      self = .null                // remove reference to arr
      arr.insert(json, at: index) // modify arr
      arr.append(json)            // modify arr
      self = .array(arr)          // restore self
    } else if case .string(var str) = self,
              case .string(let ext) = json {
      self = .null                // remove reference to str
      str.insert(contentsOf: ext, at: str.index(str.startIndex, offsetBy: index))
      str.append(ext)             // modify arr
      self = .string(str)         // restore self
    } else {
      throw Error.cannotInsert(json, self, index)
    }
  }
  
  public mutating func assign(_ member: String, to json: JSON) throws {
    if case .object(var dict) = self {
      self = .null         // remove reference to dict
      dict[member] = json  // modify dict
      self = .object(dict) // restore self
    } else {
      throw Error.cannotAppend(json, self)
    }
  }
  
  public mutating func update(_ ref: JSONReference, with json: JSON) throws {
    try self.mutate(ref) { $0 = json }
  }
  
  public mutating func update(_ ref: String, with json: JSON) throws {
    try self.mutate(ref) { $0 = json }
  }
  
  public mutating func mutate(_ ref: JSONReference, with proc: (inout JSON) throws -> Void) throws {
    try ref.mutate(&self, with: proc)
  }
  
  public mutating func mutate(array ref: JSONReference,
                              with proc: (inout [JSON]) throws -> Void) throws {
    try ref.mutate(&self) { value in
      guard case .array(var arr) = value else {
        throw JSON.Error.typeMismatch(.array, value)
      }
      value = .null
      defer {
        value = .array(arr)
      }
      try proc(&arr)
    }
  }
  
  public mutating func mutate(object ref: JSONReference,
                              with proc: (inout [String : JSON]) throws -> Void) throws {
    try ref.mutate(&self) { value in
      guard case .object(var dict) = value else {
        throw JSON.Error.typeMismatch(.object, value)
      }
      value = .null
      defer {
        value = .object(dict)
      }
      try proc(&dict)
    }
  }
  
  public mutating func mutate(_ ref: String, with proc: (inout JSON) throws -> Void) throws {
    try self.mutate(try JSON.reference(from: ref), with: proc)
  }
  
  public mutating func mutate(array ref: String,
                              with proc: (inout [JSON]) throws -> Void) throws {
    try self.mutate(array: try JSON.reference(from: ref), with: proc)
  }
  
  public mutating func mutate(object ref: String,
                              with proc: (inout [String : JSON]) throws -> Void) throws {
    try self.mutate(object: try JSON.reference(from: ref), with: proc)
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
  
  public static func reference(from str: String) throws -> JSONReference {
    if let first = str.first {
      if first == "/" {
        return try JSONPointer(str)
      } else {
        let trimmed = str.trimmingCharacters(in: CharacterSet.whitespaces)
        if trimmed.first == "." {
          return try JSONLocation("$" + trimmed)
        } else if trimmed.first == "$" {
          return try JSONLocation(trimmed)
        } else {
          return try JSONLocation("$." + trimmed)
        }
      }
    } else {
      return try JSONLocation("$")
    }
  }
}
