//
//  JSONLocation.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 18/02/2024.
//

import Foundation

public indirect enum JSONLocation: Hashable, CustomStringConvertible {
  case root
  case member(JSONLocation, String)
  case index(JSONLocation, Int)
  
  public init?(_ str: String) {
    var parser = JSONPathParser(string: str)
    guard let location = try? parser.parse().location else {
      return nil
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
        case "\u{11}": res += "\\v"
        case "\u{12}": res += "\\f"
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
