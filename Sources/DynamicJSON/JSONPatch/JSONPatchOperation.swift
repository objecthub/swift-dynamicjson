//
//  JSONPatchOperation.swift
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
/// Enumeration of individual JSONPatch operations.
///
public enum JSONPatchOperation: Codable,
                                Hashable,
                                CustomStringConvertible,
                                CustomDebugStringConvertible {
  
  /// *add(path, value)*: Add `value` to the JSON value at `path`
  case add(JSONPointer, JSON)
  
  /// *remove(path)*: Remove the value at location `path` in a JSON value.
  case remove(JSONPointer)
  
  /// *replace(path, value)*: Replace the value at location `path` with `value`.
  case replace(JSONPointer, JSON)
  
  /// *move(path, from)*: Move the value at `from` to `path`. This is equivalent
  /// to first removing the value at `from` and then adding it to `path`.
  case move(JSONPointer, JSONPointer)
  
  /// *copy(path, from)*: Copy the value at `from` to `path`. This is equivalent
  /// to looking up the value at `from` and then adding it to `path`.
  case copy(JSONPointer, JSONPointer)
  
  /// *test(path, value)*: Compares value at `path` with `value` and fails if the
  /// two are different.
  case test(JSONPointer, JSON)
  
  
  /// Collection of errors raised by functionality provided by `JSONPatchOperation`.
  public enum Error: LocalizedError, CustomStringConvertible {
    case indexOutOfBounds(Int, Int)
    case cannotRemoveRoot
    case cannotAddValue(JSONReference)
    case cannotReplaceValue(JSONReference)
    case cannotRemoveValue(JSONReference)
    case testFailed(JSONReference)
    case valueNotFound(JSONReference)
    case indexRequiredToMutateArray(JSONReference)
    case memberRequiredToMutateObject(JSONReference)
    
    public var description: String {
      switch self {
        case .indexOutOfBounds(let index, let max):
          return "index \(index) out of array bounds [0..\(max)["
        case .cannotRemoveRoot:
          return "cannot remove root"
        case .cannotAddValue(let ref):
          return "cannot add value at \(ref)"
        case .cannotRemoveValue(let ref):
          return "cannot remove value at \(ref)"
        case .cannotReplaceValue(let ref):
          return "cannot replace value at \(ref)"
        case .testFailed(let ref):
          return "test for value at location \(ref) failed"
        case .indexRequiredToMutateArray(let ref):
          return "index required to access array at \(ref)"
        case .memberRequiredToMutateObject(let ref):
          return "member required to access object at \(ref)"
        case .valueNotFound(let ref):
          return "\(ref) does not refer to a value"
      }
    }
    
    public var errorDescription: String? {
      return self.description
    }
    
    public var failureReason: String? {
      switch self {
        case .indexOutOfBounds(_, _),
             .cannotRemoveRoot,
             .cannotAddValue(_),
             .cannotRemoveValue(_),
             .testFailed(_),
             .indexRequiredToMutateArray(_),
             .memberRequiredToMutateObject(_),
             .cannotReplaceValue(_),
             .valueNotFound(_):
          return "application error"
      }
    }
  }

  /// Enumeration of JSON Patch operation types.
  public enum OperationType: String {
    case add
    case remove
    case replace
    case move
    case copy
    case test
  }
  
  public enum CodingKeys: String, CodingKey {
    case op
    case path
    case value
    case from
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let op = try container.decode(String.self, forKey: .op)
    switch op {
      case OperationType.add.rawValue:
        self = .add(try container.decode(JSONPointer.self, forKey: .path),
                    try container.decode(JSON.self, forKey: .value))
      case OperationType.remove.rawValue:
        self = .remove(try container.decode(JSONPointer.self, forKey: .path))
      case OperationType.replace.rawValue:
        self = .replace(try container.decode(JSONPointer.self, forKey: .path),
                        try container.decode(JSON.self, forKey: .value))
      case OperationType.move.rawValue:
        self = .move(try container.decode(JSONPointer.self, forKey: .path),
                     try container.decode(JSONPointer.self, forKey: .from))
      case OperationType.copy.rawValue:
        self = .copy(try container.decode(JSONPointer.self, forKey: .path),
                     try container.decode(JSONPointer.self, forKey: .from))
      case OperationType.test.rawValue:
        self = .test(try container.decode(JSONPointer.self, forKey: .path),
                     try container.decode(JSON.self, forKey: .value))
      default:
        throw DecodingError.dataCorrupted(
          DecodingError.Context(codingPath: decoder.codingPath,
                                debugDescription: "invalid JSONPatchOperation encoding"))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
      case let .add(path, value):
        try container.encode(OperationType.add.rawValue, forKey: .op)
        try container.encode(path, forKey: .path)
        try container.encode(value, forKey: .value)
      case let .remove(path):
        try container.encode(OperationType.remove.rawValue, forKey: .op)
        try container.encode(path, forKey: .path)
      case let .replace(path, value):
        try container.encode(OperationType.replace.rawValue, forKey: .op)
        try container.encode(path, forKey: .path)
        try container.encode(value, forKey: .value)
      case let .move(path, from):
        try container.encode(OperationType.move.rawValue, forKey: .op)
        try container.encode(path, forKey: .path)
        try container.encode(from, forKey: .from)
      case let .copy(path, from):
        try container.encode(OperationType.copy.rawValue, forKey: .op)
        try container.encode(path, forKey: .path)
        try container.encode(from, forKey: .from)
      case let .test(path, value):
        try container.encode(OperationType.test.rawValue, forKey: .op)
        try container.encode(path, forKey: .path)
        try container.encode(value, forKey: .value)
    }
  }
  
  /// Returns the operation type of this JSON patch operation.
  public var op: OperationType {
    switch self {
      case .add(_, _):
        return OperationType.add
      case .remove(_):
        return OperationType.remove
      case .replace(_, _):
        return OperationType.replace
      case .move(_, _):
        return OperationType.move
      case .copy(_, _):
        return OperationType.copy
      case .test(_, _):
        return OperationType.test
    }
  }
  
  /// Returns the `path` property of this JSON patch operation.
  public var path: JSONPointer {
    switch self {
      case .add(let path, _):
        return path
      case .remove(let path):
        return path
      case .replace(let path, _):
        return path
      case .move(let path, _):
        return path
      case .copy(let path, _):
        return path
      case .test(let path, _):
        return path
    }
  }
  
  /// Encodes this JSONPatchOperation value using the provided encoding strategies and
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
    return try encoder.encode(self)
  }
  
  /// Encodes this JSONPatchOperation value using the provided encoding strategies and
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
  
  /// Applies this JSON patch operation to the given JSON document, mutating this JSON
  /// document in place.
  public func apply(to json: inout JSON) throws {
    switch self {
      case .add(let path, let value):
        if let (parent, segment) = path.deselect {
          try json.mutate(
            parent,
            array: { arr in
              switch segment.index {
                case .some(.fromStart(let offset)):
                  guard offset <= arr.count else {
                    throw Error.indexOutOfBounds(offset, arr.count)
                  }
                  if offset == arr.count {
                    arr.append(value)
                  } else {
                    arr.insert(value, at: offset)
                  }
                case .some(.fromEnd(let offset)):
                  guard offset <= arr.count else {
                    throw Error.indexOutOfBounds(arr.count - offset, arr.count)
                  }
                  if offset == 0 {
                    arr.append(value)
                  } else {
                    arr.insert(value, at: arr.count - offset)
                  }
                default:
                  throw Error.indexRequiredToMutateArray(parent)
              }
            },
            object: { obj in
              if let member = segment.member {
                obj[member] = value
              } else {
                throw Error.memberRequiredToMutateObject(parent)
              }
            },
            other: { _ in
              throw Error.cannotAddValue(path)
            })
        } else {
          // throw Error.cannotAddValue(path)
          json = value
        }
      case .remove(let path):
        if let (parent, segment) = path.deselect {
          try json.mutate(
            parent,
            array: { arr in
              switch segment.index {
                case .some(.fromStart(let offset)):
                  guard offset < arr.count else {
                    throw Error.indexOutOfBounds(offset, arr.count)
                  }
                  arr.remove(at: offset)
                case .some(.fromEnd(let offset)):
                  guard offset <= arr.count && offset > 0 else {
                    throw Error.indexOutOfBounds(arr.count - offset, arr.count)
                  }
                  arr.remove(at: arr.count - offset)
                default:
                  throw Error.indexRequiredToMutateArray(parent)
              }
            },
            object: { obj in
              if let member = segment.member, obj[member] != nil {
                obj.removeValue(forKey: member)
              } else {
                throw Error.memberRequiredToMutateObject(parent)
              }
            },
            other: { _ in
              throw Error.cannotRemoveValue(path)
            })
        } else {
          throw Error.cannotRemoveValue(path)
        }
      case .replace(let path, let value):
        if let (parent, segment) = path.deselect {
          try json.mutate(
            parent,
            array: { arr in
              switch segment.index {
                case .some(.fromStart(let offset)):
                  guard offset < arr.count else {
                    throw Error.indexOutOfBounds(offset, arr.count)
                  }
                  arr[offset] = value
                case .some(.fromEnd(let offset)):
                  guard offset <= arr.count && offset > 0 else {
                    throw Error.indexOutOfBounds(arr.count - offset, arr.count)
                  }
                  arr[arr.count - offset] = value
                default:
                  throw Error.indexRequiredToMutateArray(parent)
              }
            },
            object: { obj in
              if let member = segment.member {
                if obj[member] == nil {
                  throw Error.cannotReplaceValue(path)
                } else {
                  obj[member] = value
                }
              } else {
                throw Error.memberRequiredToMutateObject(parent)
              }
            },
            other: { _ in
              throw Error.cannotReplaceValue(path)
            })
        } else {
          json = value
        }
      case .move(let path, let from):
        if let value = from.get(from: json) {
          try JSONPatchOperation.remove(from).apply(to: &json)
          try JSONPatchOperation.add(path, value).apply(to: &json)
        } else {
          throw Error.valueNotFound(from)
        }
      case .copy(let path, let from):
        if let value = from.get(from: json) {
          try JSONPatchOperation.add(path, value).apply(to: &json)
        } else {
          throw Error.valueNotFound(from)
        }
      case .test(let path, let value):
        if let current = json[ref: path] {
          guard current == value else {
            throw Error.testFailed(path)
          }
        } else {
          throw Error.valueNotFound(path)
        }
    }
  }
  
  /// Returns a pretty-printed representation of this JSONPatch operation with sorted keys in
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
    switch self {
      case .add(let path, let value):
        return "\(self.op.rawValue)(\(path), \(value)"
      case .remove(let path):
        return "\(self.op.rawValue)(\(path))"
      case .replace(let path, let value):
        return "\(self.op.rawValue)(\(path), \(value))"
      case .move(let path, let from):
        return "\(self.op.rawValue)(\(path), \(from))"
      case .copy(let path, let from):
        return "\(self.op.rawValue)(\(path), \(from))"
      case .test(let path, let value):
        return "\(self.op.rawValue)(\(path), \(value))"
    }
  }
}
