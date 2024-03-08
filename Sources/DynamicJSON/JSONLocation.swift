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

public indirect enum JSONLocation: Hashable, CustomStringConvertible {
  case root
  case member(JSONLocation, String)
  case index(JSONLocation, Int)
  
  public enum Error: LocalizedError, CustomStringConvertible {
    case invalidLocation
    
    public var description: String {
      switch self {
        case .invalidLocation:
          return "invalid JSON location identifier"
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
  
  public enum Segment: Hashable, CustomStringConvertible {
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
  
  public init(segments: [Segment]) {
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
  
  public func apply(to value: JSON) -> JSON? {
    switch self {
      case .root:
        return value
      case .member(let location, let member):
        guard let parent = location.apply(to: value),
              case .object(let dict) = parent else {
          return nil
        }
        return dict[member]
      case .index(let location, let index):
        guard let parent = location.apply(to: value),
              case .array(let arr) = parent,
              arr.indices.contains(index) else {
          return nil
        }
        return arr[index]
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
  
  public static func escapeMember(_ str: String) -> String {
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
