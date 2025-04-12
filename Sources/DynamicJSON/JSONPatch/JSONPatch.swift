//
//  JSONPatch.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 02/04/2024.
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
/// Representation of a sequence of mutations applicable to JSON documents
/// based on RFC 6902. JSON Patch defines a JSON-based document structure
/// for expressing a sequence of operations to apply to JSON data.
///
public struct JSONPatch: Codable,
                         Hashable,
                         CustomStringConvertible,
                         CustomDebugStringConvertible {
  
  /// Sequence of operations.
  public let operations: [JSONPatchOperation]
  
  /// Initializer based on a sequence of operations
  public init(operations: [JSONPatchOperation]) {
    self.operations = operations
  }
  
  /// Initializer based on a target and source JSON object
  public init(from: JSON, to: JSON, via maker: () -> JSONPatchMaker = JSONPatchMaker.init) {
    let patchMaker = maker()
    patchMaker.traverse(source: from, target: to)
    self = patchMaker.jsonPatch
  }
  
  /// Initializer based on a JSON object
  public init(_ json: JSON) throws {
    self = try json.coerce()
  }
  
  /// This initializer decodes the provided data with the given decoding strategies
  /// into a JSON patch object.
  public init(data: Data,
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
    self = try decoder.decode(JSONPatch.self, from: data)
  }
  
  /// This initializer decodes the provided string with the given decoding strategies
  /// into a JSON patch object.
  public init(string: String,
              dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
              floatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw,
              userInfo: [CodingUserInfoKey : Any]? = nil) throws {
    guard let data = string.data(using: .utf8) else {
      throw JSON.Error.erroneousEncoding
    }
    self = try .init(data: data,
                     dateDecodingStrategy: dateDecodingStrategy,
                     floatDecodingStrategy: floatDecodingStrategy,
                     userInfo: userInfo)
  }
  
  /// This initializer decodes the content at the provided URL with the given
  /// decoding strategies into a JSON patch object.
  public init(url: URL,
              dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
              floatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw,
              userInfo: [CodingUserInfoKey : Any]? = nil) throws {
    try self.init(data: try Data(contentsOf: url),
                  dateDecodingStrategy: dateDecodingStrategy,
                  floatDecodingStrategy: floatDecodingStrategy,
                  userInfo: userInfo)
  }
  
  /// Initializer used to decode JSON patch objects.
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.operations = try container.decode([JSONPatchOperation].self)
  }
  
  /// Encodes this JSON patch object using the provided encoder.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.operations)
  }
  
  /// Encodes this JSONPatch value using the provided encoding strategies and
  /// returns it as a `Data` object.
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
    return try encoder.encode(self.operations)
  }
  
  /// Encodes this JSONPatch value using the provided encoding strategies and
  /// returns it as a string.
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
  
  /// Applies this JSON patch object to the given JSON document, mutating this JSON
  /// document in place.
  public func apply(to json: inout JSON) throws {
    for operation in self.operations {
      try operation.apply(to: &json)
    }
  }
  
  /// Returns true iff this JSON patch object has no operations.
  public var isEmpty: Bool {
    return self.operations.isEmpty
  }
  
  /// Returns the number of operations encapsulated by this JSON patch object.
  public var operationCount: Int {
    return self.operations.count
  }
  
  /// Returns a pretty-printed representation of this JSONPatch value with sorted keys in
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
  
  /// Description for debugging purposes.
  public var debugDescription: String {
    return "[" + self.operations.map { $0.debugDescription }.joined(separator: ", ") + "]"
  }
}
