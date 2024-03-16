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

///
/// Generic representation of a JSON document.
///
/// Enum `JSON` encodes JSON documents using seven different cases: `null`, `boolean`,
/// `integer`, `float`, `string`, `array`, and `object`. It provides initializers for all
/// relevant Swift literals allowing a natural expression of JSON documents using Swift
/// syntax.
///
/// Enum `JSON` supports encoding and decoding of JSON documents using standard Swift
/// APIs and has convenience methods for dealing with JSON documents provided as a string
/// or `Data` object.
///
/// Besides numerous convenience methods for accessing data encapsulated in values of
/// type `JSON`, there are generic accessors based on Swift key paths, JSON pointers,
/// as well as singular JSON path queries. These can be used to extract data, but also
/// to specify transformations as well as mutations of JSON data.
///
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
  
  /// Collection of errors raised by functionality provided by enum `JSON`.
  public enum Error: LocalizedError, CustomStringConvertible {
    case initialization
    case erroneousEncoding
    case cannotAppend(JSON, JSON)
    case cannotInsert(JSON, JSON, Int)
    case cannotAssign(String, JSON)
    case typeMismatch(JSONType, JSON)
    
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
  
  // MARK: - Initializers
  
  /// Creates a JSON null value.
  public init(nilLiteral: ()) {
    self = .null
  }
  
  /// Creates a JSON boolean value.
  public init(booleanLiteral value: Bool) {
    self = .boolean(value)
  }
  
  /// Creates a JSON number from an integer literal.
  public init(integerLiteral value: Int64) {
    self = .integer(value)
  }
  
  /// Creates a JSON number from an floating-point literal.
  public init(floatLiteral value: Double) {
    self = .float(value)
  }
  
  /// Creates a JSON string.
  public init(stringLiteral value: String) {
    self = .string(value)
  }
  
  /// Creates a JSON array.
  public init(arrayLiteral elements: JSON...) {
    self = .array(elements)
  }
  
  /// Creates a JSON object from a dictionary.
  public init(dictionaryLiteral elements: (String, JSON)...) {
    var object: [String:JSON] = [:]
    for (k, v) in elements {
      object[k] = v
    }
    self = .object(object)
  }
  
  /// Coerces instances of standard Swift data types into JSON values.
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
  
  /// Initializer used to decode JSON values.
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
  
  /// Initializer used to map encodable data into JSON values. This initializer can
  /// be used to coerce a strongly typed representation of JSON-based data into a
  /// generic JSON representation.
  public init(encodable: Encodable) throws {
    self = try JSONDecoder().decode(JSON.self, from: try JSONEncoder().encode(encodable))
  }
  
  /// This initializer decodes the provided data with the given decoding strategies
  /// into a JSON value.
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
  
  /// This initializer decodes the provided string with the given decoding strategies
  /// into a JSON value.
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
  
  // MARK: - Exporting and interchanging data
  
  /// Encodes this JSON value using the provided encoding strategies and returns it as
  /// a `Data` object.
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
  
  /// Encodes this JSON value using the provided encoding strategies and returns it as
  /// a string.
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
  
  /// Coerces this JSON value into a decodable object. This method can be used to map
  /// generic JSON values into a strongly typed representation of JSON-based data.
  public func coerce<T: Decodable>() throws -> T {
    return try JSONDecoder().decode(T.self, from: try JSONEncoder().encode(self))
  }
  
  /// Encodes this JSON value using the provided encoder.
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
  
  // MARK: - Projections and accessors
  
  /// Returns the type of this JSON value.
  public var type: JSONType {
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
  
  /// Returns `true` if this JSON value represents null.
  public var isNull: Bool {
    guard case .null = self else {
      return false
    }
    return true
  }
  
  /// Returns a boolean if this JSON value represents a boolean value, otherwise
  /// `nil` is returned.
  public var boolValue: Bool? {
    guard case .boolean(let value) = self else {
      return nil
    }
    return value
  }
  
  /// Returns an integer if this JSON value represents an integer value in the
  /// `Int` range, otherwise `nil` is returned.
  public var intValue: Int? {
    guard case .integer(let value) = self,
          let res = Int(exactly: value) else {
      return nil
    }
    return res
  }
  
  /// Returns an integer if this JSON value represents an `Int64` integer value,
  /// otherwise `nil` is returned.
  public var int64Value: Int64? {
    guard case .integer(let value) = self else {
      return nil
    }
    return value
  }
  
  /// Returns a double if this JSON value represents a number, otherwise `nil` is returned.
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
  
  /// Returns a string if this value represents a JSON string, otherwise `nil` is returned.
  public var stringValue: String? {
    guard case .string(let value) = self else {
      return nil
    }
    return value
  }
  
  /// Returns an array if this value represents a JSON array, otherwise `nil` is returned.
  public var arrayValue: [JSON]? {
    guard case .array(let value) = self else {
      return nil
    }
    return value
  }
  
  /// Returns a dictionary if this value represents a JSON object, otherwise
  /// `nil` is returned.
  public var objectValue: [String: JSON]? {
    guard case .object(let value) = self else {
      return nil
    }
    return value
  }
  
  /// Returns all the direct children of this JSON value in an array. For null, boolean,
  /// numeric and string values, an empty array is returned. For JSON arrays, the array
  /// itself is returned. For JSON objects, the values of the object (without their
  /// corresponding keys) are returned in an undefined order.
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
  
  /// Applies the given function to all descendents (i.e. direct and indirect children)
  /// of this JSON value.
  public func forEachDescendant(_ proc: (JSON) throws -> Void) rethrows {
    try proc(self)
    for child in self.children {
      try child.forEachDescendant(proc)
    }
  }
  
  // MARK: - Queries and lookup of values
  
  /// Returns the JSON value at the given index in the array represented by this
  /// JSON value. If this JSON value does not represent an array or if the index
  /// is out of bounds, then `nil` is returned.
  public subscript(index: Int) -> JSON? {
    guard case .array(let array) = self, array.indices.contains(index) else {
      return nil
    }
    return array[index]
  }
  
  /// Returns the JSON value associated with the key `member` by the object represented
  /// by this JSON value. If this JSON value does not represent an object or if the object
  /// does not have such a member, `nil` will be returned?
  public subscript(member: String) -> JSON? {
    guard case .object(let dict) = self else {
      return nil
    }
    return dict[member]
  }
  
  /// Implements dynamic member lookup.
  public subscript(dynamicMember member: String) -> JSON? {
    return self[member]
  }
  
  /// Returns the JSON value referenced via the JSON reference `ref`. Supported JSON
  /// reference implementations are `JSONLocation` (singular JSON path queries) and
  /// `JSONPointer`, and every third party implementation of the `JSONReference` protocol.
  public subscript(ref ref: JSONReference) -> JSON? {
    return ref.get(from: self)
  }
  
  /// Returns the JSON value referenced via the JSON reference string `ref`. Both,
  /// JSON path syntax as well as JSON pointer syntax are supported.
  public subscript(ref ref: String) -> JSON? {
    get throws {
      return try JSON.reference(from: ref).get(from: self)
    }
  }
  
  /// Executes the given JSON path query and returns all matching JSON values in an
  /// array.
  public func query(_ path: JSONPath) throws -> [JSON] {
    return try JSONPathEvaluator(value: self).query(path)
  }
  
  /// Executes the JSON path query given in JSON path syntax and returns all matching
  /// JSON values in an array.
  public func query(_ path: String) throws -> [JSON] {
    var parser = JSONPathParser(string: path)
    return try self.query(parser.parse())
  }
  
  // MARK: - Transforming data
  
  /// Merges this JSON value with the given JSON value `other` recursively. Objects are
  /// merged key by key with values from `other` overriding values of the object represented
  /// by this JSON value. All other types of JSON values are not merged and `other` overrides
  /// this JSON value.
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
  
  /// Returns a new JSON value in which the value referenced by `ref` (any abstraction
  /// implementing the `JSONReference` procotol, such as `JSONLocation` and `JSONPointer`)
  /// was replaced with `json`.
  public func updating(_ ref: JSONReference, with json: JSON) throws -> JSON {
    return try ref.set(to: json, in: self)
  }
  
  /// Returns a new JSON value in which the value referenced by the JSON reference
  /// string `ref` (string representation of either `JSONLocation` or `JSONPointer`
  /// references) was replaced with `json`.
  public func updating(_ ref: String, with json: JSON) throws -> JSON {
    return try JSON.reference(from: ref).set(to: json, in: self)
  }
  
  // MARK: - Mutating data
  
  /// Mutates this JSON value if it represents either an array or a string by appending
  /// the given JSON value `json`. For arrays, `json` is appended as a new element. For
  /// strings it is expected that `json` also refers to a string and `json` gets appended
  /// as a string. For all other types of JSON values, an error is thrown.
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
  
  /// Mutates this JSON value if it represents either an array or a string by inserting
  /// the given JSON value `json`. For arrays, `json` is inserted as a new element at
  /// `index`. For strings it is expected that `json` also refers to a string and `json`
  /// gets inserted into this string at position `index`. For all other types of JSON
  /// values, an error is thrown.
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
  
  /// Adds a new key/value mapping or updates an existing key/value mapping in this
  /// JSON object. If this JSON value is not an object, an error is thrown.
  public mutating func assign(_ member: String, to json: JSON) throws {
    if case .object(var dict) = self {
      self = .null         // remove reference to dict
      dict[member] = json  // modify dict
      self = .object(dict) // restore self
    } else {
      throw Error.cannotAppend(json, self)
    }
  }
  
    /// Returns a new JSON value in which the value referenced by `ref` (any abstraction
    /// implementing the `JSONReference` procotol, such as `JSONLocation` and `JSONPointer`)
    /// was replaced with `json`.
  
  /// Replaces the value the location reference `ref` is referring to with `json`. The
  /// replacement is done in place, i.e. it mutates this JSON value. `ref` can be
  /// implemented by any abstraction implementing the `JSONReference` procotol, such as
  /// `JSONLocation` (for singular JSON path queries) and `JSONPointer`.
  public mutating func update(_ ref: JSONReference, with json: JSON) throws {
    try self.mutate(ref) { $0 = json }
  }
  
  /// Replaces the value the location reference string `ref` is referring to with `json`.
  /// The replacement is done in place, i.e. it mutates this JSON value. `ref` is a string
  /// representation of either `JSONLocation` or `JSONPointer` references.
  public mutating func update(_ ref: String, with json: JSON) throws {
    try self.mutate(ref) { $0 = json }
  }
  
  /// Mutates the JSON value the reference `ref` is referring to with function `proc`.
  /// `proc` receives a reference to the JSON value, allowing efficient in place mutations
  /// without automatically doing any copying. `ref` can be implemented by any abstraction
  /// implementing the `JSONReference` procotol, such as `JSONLocation` (for singular JSON
  /// path queries) and `JSONPointer`.
  public mutating func mutate(_ ref: JSONReference, with proc: (inout JSON) throws -> Void) throws {
    try ref.mutate(&self, with: proc)
  }
  
  /// Mutates the JSON array the reference `ref` is referring to with function `proc`.
  /// `proc` receives a reference to the array, allowing efficient in place mutations
  /// without automatically doing any copying. `ref` can be implemented by any abstraction
  /// implementing the `JSONReference` procotol, such as `JSONLocation` (for singular JSON
  /// path queries) and `JSONPointer`.
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
  
  /// Mutates the JSON object the reference `ref` is referring to with function `proc`.
  /// `proc` receives a reference to the dictionary of the object, allowing efficient in
  /// place mutations without automatically doing any copying. `ref` can be implemented
  /// by any abstraction implementing the `JSONReference` procotol, such as `JSONLocation`
  /// (for singular JSON path queries) and `JSONPointer`.
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
  
  /// Mutates the JSON value the reference string `ref` is referring to with function `proc`.
  /// `proc` receives a reference to the JSON value, allowing efficient in place mutations
  /// without automatically doing any copying. `ref` is a string representation of either
  /// `JSONLocation` or `JSONPointer` references.
  public mutating func mutate(_ ref: String, with proc: (inout JSON) throws -> Void) throws {
    try self.mutate(try JSON.reference(from: ref), with: proc)
  }
  
  /// Mutates the JSON array the reference string `ref` is referring to with function `proc`.
  /// `proc` receives a reference to the array, allowing efficient in place mutations
  /// without automatically doing any copying. `ref` is a string representation of either
  /// `JSONLocation` or `JSONPointer` references.
  public mutating func mutate(array ref: String,
                              with proc: (inout [JSON]) throws -> Void) throws {
    try self.mutate(array: try JSON.reference(from: ref), with: proc)
  }
  
  /// Mutates the JSON object the reference string `ref` is referring to with function `proc`.
  /// `proc` receives a reference to the dictionary of the object, allowing efficient in
  /// place mutations without automatically doing any copying. `ref` is a string
  /// representation of either `JSONLocation` or `JSONPointer` references.
  public mutating func mutate(object ref: String,
                              with proc: (inout [String : JSON]) throws -> Void) throws {
    try self.mutate(object: try JSON.reference(from: ref), with: proc)
  }
  
  // MARK: - String representations
  
  /// Returns a pretty-printed representation of this JSON value with sorted keys in
  /// object representations. Dates are encoded using ISO 8601. Floating-point numbers
  /// denoting infinity are represented with the term "Infinity" respectively "-Infinity".
  /// NaN values are denoted with "NaN".
  public var description: String {
    return (try? self.string(
             formatting: [.prettyPrinted, .sortedKeys],
             dateEncodingStrategy: .iso8601,
             floatEncodingStrategy: .convertToString(positiveInfinity: "Infinity",
                                                     negativeInfinity: "-Infinity",
                                                     nan: "NaN"))) ?? "<invalid JSON>"
  }
  
  /// Returns a description of this JSON value for debugging purposes.
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
  
  // MARK: - Utilities
  
  /// Parse the given string either as a `JSONLocation` (i.e. using the JSON path
  /// syntax) or `JSONPointer` (i.e. using the JSON path syntax). Empty strings or
  /// strings starting with "/" are parsed as `JSONPointer` references; all other
  /// strings are interpreted as `JSONLocation` references (with some flexibility
  /// to omit the initial "$", for backward compatibility purposes).
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
