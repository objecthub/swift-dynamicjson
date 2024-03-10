//
//  JSONLocation.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 18/02/2024.
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

public indirect enum JSONLocation: JSONReference,
                                   Codable,
                                   Hashable,
                                   CustomStringConvertible {
  case root
  case member(JSONLocation, String)
  case index(JSONLocation, Int)
  
  public enum Error: LocalizedError, CustomStringConvertible {
    case invalidLocation
    
    public var description: String {
      switch self {
        case .invalidLocation:
          return "JSON path query does not denote a location"
      }
    }
    
    public var errorDescription: String? {
      return self.description
    }
    
    public var failureReason: String? {
      switch self {
        case .invalidLocation:
          return "parsing error"
      }
    }
  }
  
  public enum Segment: Codable, Hashable, CustomStringConvertible {
    case member(String)
    case index(Int)
    
    public var description: String {
      switch self {
        case .member(let member):
          return "['\(JSONLocation.escapeMember(member))']"
        case .index(let index):
          return "[\(index)]"
      }
    }
  }
  
  public init(_ str: String) throws {
    var parser = JSONPathParser(string: str)
    guard let location = try parser.parse().location else {
      throw Error.invalidLocation
    }
    self = location
  }
  
  public init<S: Sequence>(segments: S) where S.Element == Segment {
    var location: JSONLocation = .root
    for segment in segments {
      switch segment {
        case .member(let member):
          location = .member(location, member)
        case .index(let index):
          location = .index(location, index)
      }
    }
    self = location
  }
  
  public init(from codingPath: [CodingKey]) {
    self.init(segments:
      codingPath.map { component in
        if let i = component.intValue {
          return .index(i)
        } else {
          return .member(component.stringValue)
        }
      }
    )
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    try self.init(try container.decode(String.self))
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.description)
  }
  
  public var pointer: JSONPointer {
    return JSONPointer(components: self.segments.map{ segment in
      switch segment {
        case .member(let member):
          return member
        case .index(let index):
          return "\(index)"
      }
    })
  }
  
  public var path: JSONPath {
    switch self {
      case .root:
        return .self
      case .member(let location, let member):
        return .select(location.path, .children([.member(member)]))
      case .index(let location, let index):
        return .select(location.path, .children([.index(index)]))
    }
  }
  
  public var segments: [Segment] {
    var res: [Segment] = []
    self.insert(into: &res)
    return res
  }
  
  private func insert(into segments: inout [Segment]) {
    switch self {
      case .member(let location, let member):
        location.insert(into: &segments)
        segments.append(.member(member))
      case .index(let location, let member):
        location.insert(into: &segments)
        segments.append(.index(member))
      default:
        break
    }
  }
  
  public func get(from value: JSON) -> JSON? {
    switch self {
      case .root:
        return value
      case .member(let location, let member):
        guard let parent = location.get(from: value),
              case .object(let dict) = parent else {
          return nil
        }
        return dict[member]
      case .index(let location, let index):
        guard let parent = location.get(from: value),
              case .array(let arr) = parent,
              arr.indices.contains(index) else {
          return nil
        }
        return arr[index]
    }
  }
  
  public func set(to json: JSON, in value: JSON) throws -> JSON {
    return try self.set(value, at: self.segments, index: 0, to: json)
  }
  
  private func set(_ value: JSON,
                   at segments: [JSONLocation.Segment],
                   index current: Int,
                   to json: JSON) throws -> JSON {
    if current < segments.count {
      switch segments[current] {
        case .index(let index):
          guard case .array(var array) = value, array.indices.contains(index) else {
            throw JSONReferenceError.erroneousIndexSelection(value, index)
          }
          array[index] = try self.set(array[index], at: segments, index: current + 1, to: json)
          return .array(array)
        case .member(let key):
          guard case .object(var dict) = value, let rhsval = dict[key] else {
            throw JSONReferenceError.erroneousMemberSelection(value, key)
          }
          dict[key] = try self.set(rhsval, at: segments, index: current + 1, to: json)
          return .object(dict)
      }
    } else {
      return json
    }
  }
  
  public func mutate(_ json: inout JSON, with proc: (inout JSON) throws -> Void) throws {
    var iter = self.segments.makeIterator()
    try self.mutate(&json, next: &iter, with: proc)
  }
  
  public func mutate(_ value: inout JSON,
                     next iter: inout [JSONLocation.Segment].Iterator,
                     with proc: (inout JSON) throws -> Void) throws {
    if let segment = iter.next() {
      switch segment {
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
        case .index(let index):
          guard case .array(var arr) = value, arr.indices.contains(index) else {
            return
          }
          var json = arr[index]
          value = .null
          arr[index] = .null
          defer {
            arr[index] = json
            value = .array(arr)
          }
          try self.mutate(&json, next: &iter, with: proc)
      }
    } else {
      try proc(&value)
    }
  }
  
  public var description: String {
    switch self {
      case .root:
        return "$"
      case .member(let location, let member):
        return "\(location)['\(JSONLocation.escapeMember(member))']"
      case .index(let location, let index):
        return "\(location)[\(index)]"
    }
  }
  
  internal static func escapeMember(_ str: String) -> String {
    var res = ""
    for c in str {
      switch c {
        case "\u{7}":  res += "\\a"
        case "\u{8}":  res += "\\b"
        case "\t":     res += "\\t"
        case "\n":     res += "\\n"
        case "\u{b}":  res += "\\v"
        case "\u{c}":  res += "\\f"
        case "\r":     res += "\\r"
        case "\"":     res += "\\\""
        case "'":      res += "\\'"
        case "\\":     res += "\\\\"
        default:       res.append(c)
      }
    }
    return res
  }
}
