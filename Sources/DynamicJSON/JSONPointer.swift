//
//  JSONPointer.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 09/03/2024.
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
/// `JSONPointer` implements the `JSONReference` protocol based on RFC 6901
/// (JavaScript Object Notation (JSON) Pointer). A `JSONPointer` value is defined
/// in terms of a sequence of reference tokens used to navigate through the
/// structure of a JSON document.
///
public struct JSONPointer: JSONReference,
                           Codable,
                           Hashable,
                           CustomStringConvertible {
  private let tokens: [ReferenceToken]
  
  private enum ReferenceToken: Hashable, CustomStringConvertible {
    case member(String)
    case index(String, Int?)
    
    public var string: String {
      switch self {
        case .member(let member):
          return member
        case .index(let member, _):
          return member
      }
    }
    
    public var description: String {
      switch self {
        case .member(let member):
          return "/\(JSONPointer.escapeMember(member))"
        case .index(let member, _):
          return "/\(member)"
      }
    }
  }
  
  /// Collection of errors raised by functionality provided by enum `JSONLocation`.
  public enum Error: LocalizedError, CustomStringConvertible {
    case rootMissing
    case invalidPointer
    
    public var description: String {
      switch self {
        case .rootMissing:
          return "missing initial '/'"
        case .invalidPointer:
          return "invalid JSON pointer identifier"
      }
    }
    
    public var errorDescription: String? {
      return self.description
    }
    
    public var failureReason: String? {
      switch self {
        case .rootMissing:
          return "parsing error"
        case .invalidPointer:
          return "parsing error"
      }
    }
  }
  
  private init(tokens: [ReferenceToken]) {
    self.tokens = tokens
  }
  
  private static let digits: Set<Character> = [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
  ]
  
  /// Initialize a `JSONPointer` reference using a string representation of a JSON
  /// pointer based on RFC 6901.
  public init(_ jsonPointer: String) throws {
    let cs = jsonPointer.split(separator: "/", omittingEmptySubsequences: false)
    if let initial = cs.first {
      guard initial.isEmpty else {
        throw Error.rootMissing
      }
      self.init(components: cs.dropFirst().map { JSONPointer.unescapeMember(String($0)) })
    } else {
      self.init(components: [])
    }
  }
  
  /// Initializes a new `JSONPointer` value based on a sequence of strings
  /// each representing a reference token.
  public init<S: Sequence>(components: S) where S.Element == String {
    var tokens: [ReferenceToken] = []
    for component in components {
      if let first = component.first {
        if first == "-" && component.count == 1 {
          tokens.append(.index(component, nil))
        } else if component.allSatisfy({ ch in JSONPointer.digits.contains(ch) }) {
          if first == "0" && component.count > 1 {
            tokens.append(.member(component))
          } else if let n = Int(component) {
            tokens.append(.index(component, n))
          } else {
            tokens.append(.member(component))
          }
        } else {
          tokens.append(.member(component))
        }
      } else {
        tokens.append(.member(""))
      }
    }
    self.init(tokens: tokens)
  }
  
  /// Initialize a `JSONPointer` reference from an array of coding keys.
  public init(from codingPath: [CodingKey]) {
    self.init(components:
      codingPath.map { component in
        if let i = component.intValue {
          return "\(i)"
        } else {
          return component.stringValue
        }
      }
    )
  }
  
  /// The reference tokens defining this `JSONPointer` value.
  public var components: [String] {
    var components: [String] = []
    for token in tokens {
      components.append(token.string)
    }
    return components
  }
  
  /// Initialize a `JSONPointer` reference using a decoder.
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    try self.init(try container.decode(String.self))
  }
  
  /// Encode a `JSONPointer` reference using the given encoder.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.description)
  }
  
  /// Retrieve value at which this reference is pointing from JSON document `value`.
  /// If the reference does not match any value, `nil` is returned.
  public func get(from value: JSON) -> JSON? {
    var res = value
    for token in self.tokens {
      switch token {
        case .member(let member):
          guard case .object(let dict) = res,
                let next = dict[member] else {
            return nil
          }
          res = next
        case .index(let member, let index):
          switch res {
            case .array(let arr):
              guard let n = index, n >= 0, n < arr.count else {
                return nil
              }
              res = arr[n]
            case .object(let dict):
              guard let next = dict[member] else {
                return nil
              }
              res = next
            default:
              return nil
          }
      }
    }
    return res
  }
  
  /// Replace value at which this reference is pointing with `json` within JSON
  /// document `value`. If the reference does not match any value, an error is thrown.
  public func set(to json: JSON, in value: JSON) throws -> JSON {
    return try self.set(value, index: 0, to: json)
  }
  
  private func set(_ value: JSON, index current: Int, to json: JSON) throws -> JSON {
    if current < self.tokens.count {
      switch self.tokens[current] {
        case .member(let member):
          guard case .object(var dict) = value, let rhsval = dict[member] else {
            throw JSONReferenceError.erroneousMemberSelection(value, member)
          }
          dict[member] = try self.set(rhsval, index: current + 1, to: json)
          return .object(dict)
        case .index(let member, let index):
          switch value {
            case .array(var arr):
              if let n = index, arr.indices.contains(n) {
                arr[n] = try self.set(arr[n], index: current + 1, to: json)
              } else if current + 1 == self.tokens.count {
                arr.append(json)
              } else {
                if let index {
                  throw JSONReferenceError.erroneousIndexSelection(value, index)
                } else {
                  throw JSONReferenceError.erroneousMemberSelection(value, member)
                }
              }
              return .array(arr)
            case .object(var dict):
              guard let rhsval = dict[member] else {
                throw JSONReferenceError.erroneousMemberSelection(value, member)
              }
              dict[member] = try self.set(rhsval, index: current + 1, to: json)
              return .object(dict)
            default:
              if let index {
                throw JSONReferenceError.erroneousIndexSelection(value, index)
              } else {
                throw JSONReferenceError.erroneousMemberSelection(value, member)
              }
          }
      }
    } else {
      return json
    }
  }
  
  /// Mutate value at which this reference is pointing within JSON document `value`
  /// with function `proc`. `proc` is provided a reference, enabling efficient,
  /// in-place mutations that do not trigger copying large parts of the JSON document.
  public func mutate(_ json: inout JSON, with proc: (inout JSON) throws -> Void) throws {
    var iter = self.tokens.makeIterator()
    try self.mutate(&json, next: &iter, with: proc)
  }
  
  private func mutate(_ value: inout JSON,
                      next iter: inout [ReferenceToken].Iterator,
                      with proc: (inout JSON) throws -> Void) throws {
    if let token = iter.next() {
      switch token {
        case .member(let member):
          guard case .object(var dict) = value,
                var json = dict[member] else {
            throw JSONReferenceError.erroneousMemberSelection(value, member)
          }
          value = .null
          dict[member] = nil
          defer {
            dict[member] = json
            value = .object(dict)
          }
          try self.mutate(&json, next: &iter, with: proc)
        case .index(let member, let index):
          if case .array(var arr) = value {
            if let index {
              guard arr.indices.contains(index) else {
                throw JSONReferenceError.erroneousIndexSelection(value, index)
              }
              var json = arr[index]
              value = .null
              arr[index] = .null
              defer {
                arr[index] = json
                value = .array(arr)
              }
              try self.mutate(&json, next: &iter, with: proc)
            } else {
              var json = JSON.null
              value = .null
              defer {
                value = .array(arr)
              }
              try self.mutate(&json, next: &iter, with: proc)
              arr.append(json)
            }
          } else if case .object(var dict) = value, var json = dict[member] {
            value = .null
            dict[member] = nil
            defer {
              dict[member] = json
              value = .object(dict)
            }
            try self.mutate(&json, next: &iter, with: proc)
          } else if let index {
            throw JSONReferenceError.erroneousIndexSelection(value, index)
          } else {
            throw JSONReferenceError.erroneousMemberSelection(value, member)
          }
      }
    } else {
      try proc(&value)
    }
  }
  
  /// Returns a textual description of this `JSONPointer`.
  public var description: String {
    return self.tokens.isEmpty ? "" : self.tokens.map{ $0.description }.joined()
  }
  
  private static func unescapeMember(_ str: String) -> String {
    var res = ""
    var escaped = false
    for c in str {
      switch c {
        case "~":
          if escaped {
            res.append("~")
          }
          escaped = true
        case "0":
          res.append(escaped ? "~" : "0")
          escaped = false
        case "1":
          res.append(escaped ? "/" : "1")
          escaped = false
        default:
          if escaped {
            res.append("~")
          }
          res.append(c)
          escaped = false
      }
    }
    return escaped ? res + "~" : res
  }
  
  private static func escapeMember(_ str: String) -> String {
    var res = ""
    for c in str {
      switch c {
        case "~": res += "~0"
        case "/": res += "~1"
        default:  res.append(c)
      }
    }
    return res
  }
}
