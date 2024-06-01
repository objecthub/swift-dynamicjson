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

///
/// `JSONLocation` values are JSONPath-based implementations of the `JSONReference`
/// protocol. A `JSONLocation` value is defined in terms of a sequence of member names
/// and array indices used to navigate through the structure of a JSON document.
/// As opposed to `JSONPath` queries, `JSONLocation` references refer to at most one
/// value within a JSON document.
///
public indirect enum JSONLocation: SegmentableJSONReference,
                                   Codable,
                                   Hashable,
                                   CustomStringConvertible {
  case root
  case member(JSONLocation, String)
  case index(JSONLocation, Int)
  
  /// Collection of errors raised by functionality provided by enum `JSONLocation`.
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
  
  /// Representation of a segment of singular JSONPath queries (which are the
  /// foundation of `JSONLocation` references).
  public enum Segment: JSONReferenceSegment, Codable, Hashable, CustomStringConvertible {
    case member(String)
    case index(Int)
    
    public var index: JSONReferenceSegmentIndex? {
      switch self {
        case .member(_):
          return nil
        case .index(let index):
          return index < 0 ? .fromEnd(-index) : .fromStart(index)
      }
    }
    
    public var member: String? {
      switch self {
        case .member(let member):
          return member
        case .index(let index):
          return String(index)
      }
    }
    
    public var description: String {
      switch self {
        case .member(let member):
          return "['\(JSONLocation.escapeMember(member))']"
        case .index(let index):
          return "[\(index)]"
      }
    }
  }
  
  /// Initialize a `JSONLocation` reference via JSONPath syntax for singular queries.
  public init(_ str: String) throws {
    var parser = JSONPathParser(string: str)
    guard let location = try parser.parse().location else {
      throw Error.invalidLocation
    }
    self = location
  }
  
  /// Initialize a `JSONLocation` from a sequence of segments.
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
  
  /// Initialize a `JSONLocation` reference from an array of coding keys.
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
  
  /// Initializes a `JSONLocation` reference by composing a relative location with
  /// a `base` location.
  public init(_ location: JSONLocation, relativeTo base: JSONLocation = .root) {
    switch location {
      case .root:
        self = base
      case .member(let parent, let member):
        self = .member(.init(parent, relativeTo: base), member)
      case .index(let parent, let index):
        self = .index(.init(parent, relativeTo: base), index)
    }
  }
  
  /// Initialize a `JSONLocation` reference using a decoder.
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    try self.init(try container.decode(String.self))
  }
  
  /// Encode a `JSONLocation` reference using the given encoder.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.description)
  }
  
  /// Returns a new JSONLocation with the given member selected.
  public func select(member: String) -> JSONLocation {
    return .member(self, member)
  }
  
  /// Returns a new JSONLocation with the given index selected.
  public func select(index: Int) -> JSONLocation {
    return .index(self, index)
  }
  
  /// The segments defining this `JSONLocation`.
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
  
  /// Returns the number of segments of this JSONLocation.
  public var segmentCount: Int {
    switch self {
      case .root:
        return 0
      case .member(let location, _):
        return location.segmentCount + 1
      case .index(let location, _):
        return location.segmentCount + 1
    }
  }
  
  /// Returns a new JSONLocation by appending the given segment.
  public func select(segment: Segment) -> JSONLocation {
    switch segment {
      case .member(let member):
        return .member(self, member)
      case .index(let index):
        return .index(self, index)
    }
  }
  
  /// Decomposes this JSONLocation into a parent location and the last segment of this
  /// JSONLocation.
  public var deselect: (JSONLocation, Segment)? {
    switch self {
      case .root:
        return nil
      case .member(let parent, let member):
        return (parent, .member(member))
      case .index(let parent, let index):
        return (parent, .index(index))
    }
  }
  
  /// Returns true if this location is a prefix of `location`.
  public func isPrefix(of location: JSONLocation, allowEqual: Bool = true) -> Bool {
    let segments = self.segments
    let locationSegments = location.segments
    return locationSegments.starts(with: segments) &&
           (allowEqual || segments.count < locationSegments.count)
  }
  
  /// Returns a new location that, relative to `prefix` is equivalent to this location.
  public func relative(to prefix: JSONLocation) -> JSONLocation? {
    let segments = self.segments
    let prefixSegments = prefix.segments
    guard segments.starts(with: prefixSegments) else {
      return nil
    }
    return JSONLocation(segments: self.segments.dropFirst(prefixSegments.count))
  }
  
  /// Returns a matching `JSONPointer` reference if possible. `JSONLocation` references
  /// which use negative indices cannot be converted to `JSONPointer`.
  public var pointer: JSONPointer? {
    var components: [String] = []
    for segment in self.segments {
      switch segment {
        case .member(let member):
          components.append(member)
        case .index(let index):
          guard index >= 0 else {
            return nil
          }
          components.append("\(index)")
      }
    }
    return JSONPointer(components: components)
  }
  
  /// Returns a matching `JSONPath` query.
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
  
  /// Retrieve value at which this reference is pointing from JSON document `value`.
  /// If the reference does not match any value, `nil` is returned.
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
              case .array(let arr) = parent else {
          return nil
        }
        if arr.indices.contains(index) {
          return arr[index]
        } else if index < 0 && arr.count + index >= 0 {
          return arr[arr.count + index]
        } else {
          return nil
        }
    }
  }
  
  /// Replace value at which this reference is pointing with `json` within JSON
  /// document `value`. If the reference does not match any value, an error is thrown.
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
          guard case .array(var arr) = value else {
            throw JSONReferenceError.erroneousIndexSelection(value, index)
          }
          let i: Int
          if arr.indices.contains(index) {
            i = index
          } else if index < 0 && arr.count + index >= 0 {
            i = arr.count + index
          } else {
            throw JSONReferenceError.erroneousIndexSelection(value, index)
          }
          arr[i] = try self.set(arr[i], at: segments, index: current + 1, to: json)
          return .array(arr)
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
  
  /// Mutate value at which this reference is pointing within JSON document `value`
  /// with function `proc`. `proc` is provided a reference, enabling efficient,
  /// in-place mutations that do not trigger copying large parts of the JSON document.
  public func mutate(_ json: inout JSON,
                     with proc: (inout JSON) throws -> Void,
                     insert: Bool = false) throws {
    var iter = self.segments.makeIterator()
    try self.mutate(&json, next: &iter, with: proc, insert: insert)
  }
  
  private func mutate(_ value: inout JSON,
                      next iter: inout [JSONLocation.Segment].Iterator,
                      with proc: (inout JSON) throws -> Void,
                      insert: Bool) throws {
    if let segment = iter.next() {
      switch segment {
        case .member(let member):
          guard case .object(var dict) = value else {
            throw JSONReferenceError.erroneousMemberSelection(value, member)
          }
          value = .null
          if var json = dict[member] {
            dict[member] = nil
            defer {
              dict[member] = json
              value = .object(dict)
            }
            try self.mutate(&json, next: &iter, with: proc, insert: insert)
          } else if insert {
            var json = JSON.null
            defer {
              value = .object(dict)
            }
            try self.mutate(&json, next: &iter, with: proc, insert: insert)
            dict[member] = json
          } else {
            throw JSONReferenceError.erroneousMemberSelection(value, member)
          }
        case .index(let index):
          guard case .array(var arr) = value else {
            throw JSONReferenceError.erroneousIndexSelection(value, index)
          }
          let i: Int
          if arr.indices.contains(index) {
            i = index
          } else if index < 0 && arr.count + index >= 0 {
            i = arr.count + index
          } else {
            throw JSONReferenceError.erroneousIndexSelection(value, index)
          }
          var json = arr[i]
          value = .null
          arr[i] = .null
          defer {
            arr[i] = json
            value = .array(arr)
          }
          try self.mutate(&json, next: &iter, with: proc, insert: insert)
      }
    } else {
      try proc(&value)
    }
  }
  
  /// Returns a textual description of this `JSONLocation`.
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
