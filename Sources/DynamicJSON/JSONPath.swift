//
//  JSONPath.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 13/02/2024.
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

public indirect enum JSONPath: Hashable, CustomStringConvertible {
  case `self`
  case current
  case select(JSONPath, Segment)
  
  public init(query: String, strict: Bool = true) throws {
    var parser = JSONPathParser(string: query, strict: strict)
    self = try parser.parse()
  }
  
  public var isSingular: Bool {
    switch self {
      case .self:
        return true
      case .current:
        return true
      case .select(let path, let segment):
        return path.isSingular && segment.isSingular
    }
  }
  
  public var location: JSONLocation? {
    switch self {
      case .self:
        return .root
      case .select(let path, .children(let selectors)):
        if let parentLocation = path.location, selectors.count == 1 {
          switch selectors[0] {
            case .member(let member):
              return .member(parentLocation, member)
            case .index(let index):
              return .index(parentLocation, index)
            default:
              return nil
          }
        }
        fallthrough
      default:
        return nil
    }
  }
  
  public var description: String {
    switch self {
      case .self:
        return "$"
      case .current:
        return "@"
      case .select(let path, let segment):
        return "\(path)\(segment)"
    }
  }
  
  public static func children(_ path: JSONPath, _ selector: Selector) -> JSONPath {
    return .select(path, .children([selector]))
  }
  
  public static func descendants(_ path: JSONPath, _ selector: Selector) -> JSONPath {
    return .select(path, .descendants([selector]))
  }
  
  public enum Segment: Hashable, CustomStringConvertible {
    case children([Selector])
    case descendants([Selector])
    
    public var isDescendant: Bool {
      switch self {
        case .children(_):
          return false
        case .descendants(_):
          return true
      }
    }
    
    public var isSingular: Bool {
      switch self {
        case .children(let selectors):
          return selectors.count == 1 && selectors[0].isSingular
        case .descendants(_):
          return false
      }
    }
    
    public var selectors: [Selector] {
      switch self {
        case .children(let selectors):
          return selectors
        case .descendants(let selectors):
          return selectors
      }
    }
    
    private func canUseShorthand(for member: String) -> Bool {
      var first = true
      for ch in member {
        let scalars = ch.unicodeScalars
        guard ch.isLetter
              || !first && ch.isHexDigit
              || ch == "_"
              || !first && ch == "-"
              || scalars.allSatisfy({ c in c.value >= 0x80 && c.value <= 0xD7FF })
              || scalars.allSatisfy({ c in c.value >= 0xE000 && c.value <= 0x10FFFF }) else {
          return false
        }
        first = false
      }
      return true
    }
    
    public var description: String {
      var res = ""
      var selectors: [Selector]
      switch self {
        case .children(let sel):
          selectors = sel
        case .descendants(let sel):
          selectors = sel
          res.append(".")
      }
      if selectors.count == 0 {
        return "\(res)[]"
      } else if selectors.count == 1 {
        switch selectors[0] {
          case .wildcard:
            return "\(res).*"
          case .member(let member):
            if self.canUseShorthand(for: member) {
              return "\(res).\(member)"
            } else if res.isEmpty {
              return "['\(JSONLocation.escapeMember(member))']"
            } else {
              return "..['\(JSONLocation.escapeMember(member))']"
            }
          default:
            if res.isEmpty {
              return "[\(selectors[0])]"
            } else {
              return "..[\(selectors[0])]"
            }
        }
      } else {
        if res.isEmpty {
          return "[\(selectors.map { x in x.description }.joined(separator: ", "))]"
        } else {
          return "..[\(selectors.map { x in x.description }.joined(separator: ", "))]"
        }
      }
    }
  }
  
  public enum Selector: Hashable, CustomStringConvertible {
    case wildcard
    case member(String)
    case index(Int)
    case slice(Int?, Int?, Int?)
    case filter(Expression)
    
    public var isSingular: Bool {
      switch self {
        case .wildcard:
          return false
        case .member(_):
          return true
        case .index(_):
          return true
        case .slice(_, _, _):
          return false
        case .filter(_):
          return false
      }
    }
    
    public var description: String {
      switch self {
        case .wildcard:
          return "*"
        case .member(let member):
          return "'\(JSONLocation.escapeMember(member))'"
        case .index(let n):
          return String(n)
        case .slice(nil, nil, nil):
          return ":"
        case .slice(.some(let start), nil, nil):
          return "\(start):"
        case .slice(nil, .some(let end), nil):
          return ":\(end)"
        case .slice(nil, nil, .some(let step)):
          return "::\(step)"
        case .slice(.some(let start), .some(let end), nil):
          return "\(start):\(end)"
        case .slice(.some(let start), nil, .some(let step)):
          return "\(start)::\(step)"
        case .slice(nil, .some(let end), .some(let step)):
          return ":\(end):\(step)"
        case .slice(.some(let start), .some(let end), .some(let step)):
          return "\(start):\(end):\(step)"
        case .filter(let condition):
          return "? \(condition)"
      }
    }
  }
  
  public indirect enum Expression: Hashable, CustomStringConvertible {
    case `null`
    case `true`
    case `false`
    case integer(Int64)
    case float(Double)
    case string(String)
    case variable(String)
    case query(JSONPath)
    case singularQuery(JSONPath)
    case call(String, [Expression])
    case prefix(UnaryOperator, Expression)
    case operation(Expression, BinaryOperator, Expression)
    
    public func description(within context: Expression) -> String {
      switch (self, context) {
        case (.null, _), (.true, _), (.false, _),
             (.integer(_), _), (.float(_), _), (.string(_), _), (.variable(_), _),
             (.query(_), _), (.call(_, _), _):
          return self.description
        case (.operation(_, _, _), .prefix(_, _)):
          return "(\(self))"
        case (.operation(_, let op, _), .operation(_, let cop, _)):
          if cop.precedence > op.precedence {
            return "(\(self))"
          }
          fallthrough
        default:
          return self.description
      }
    }
    
    public var description: String {
      switch self {
        case .null:
          return "null"
        case .true:
          return "true"
        case .false:
          return "false"
        case .integer(let x):
          return String(x)
        case .float(let x):
          return String(x)
        case .string(let str):
          return "'\(str)'"
        case .variable(let ident):
          return ident
        case .query(let path):
          return path.description
        case .singularQuery(let path):
          return path.description
        case .call(let ident, let args):
          return "\(ident)(\(args.map { x in x.description }.joined(separator: ", ")))"
        case .prefix(let op, let oper):
          return "\(op)\(oper.description(within: self))"
        case .operation(let lhs, let op, let rhs):
          return "\(lhs.description(within: self)) \(op) \(rhs.description(within: self))"
      }
    }
  }
  
  public enum UnaryOperator: Hashable, CustomStringConvertible {
    case not
    case negate
    
    public var description: String {
      switch self {
        case .not:
          return "!"
        case .negate:
          return "-"
      }
    }
  }
  
  public enum BinaryOperator: Hashable, CustomStringConvertible {
    case equals
    case notEquals
    case lessThan
    case lessThanEquals
    case greaterThan
    case greaterThanEquals
    case or
    case and
    case plus
    case minus
    case mult
    case divide
    
    var precedence: Int {
      switch self {
        case .or:
          return 0
        case .and:
          return 1
        case .equals:
          return 2
        case .notEquals:
          return 2
        case .lessThan:
          return 2
        case .lessThanEquals:
          return 2
        case .greaterThan:
          return 2
        case .greaterThanEquals:
          return 2
        case .plus:
          return 3
        case .minus:
          return 3
        case .mult:
          return 4
        case .divide:
          return 4
      }
    }
    
    public var description: String {
      switch self {
        case .equals:
          return "=="
        case .notEquals:
          return "!="
        case .lessThan:
          return "<"
        case .lessThanEquals:
          return "<="
        case .greaterThan:
          return ">"
        case .greaterThanEquals:
          return ">="
        case .or:
          return "||"
        case .and:
          return "&&"
        case .plus:
          return "+"
        case .minus:
          return "-"
        case .mult:
          return "*"
        case .divide:
          return "/"
      }
    }
  }
  
  public var isRelative: Bool {
    switch self {
      case .self:
        return false
      case .current:
        return true
      case .select(let path, _):
        return path.isRelative
    }
  }
  
  public var segments: [Segment] {
    var res: [Segment] = []
    self.insert(into: &res)
    return res
  }
  
  private func insert(into segments: inout [Segment]) {
    switch self {
      case .self, .current:
        break
      case .select(let path, let segment):
        path.insert(into: &segments)
        segments.append(segment)
    }
  }
}
