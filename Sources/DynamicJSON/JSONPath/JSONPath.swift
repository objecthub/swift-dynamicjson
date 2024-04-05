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

///
/// Enumeration `JSONPath` represents JSONPath queries based on RFC 9535
/// (JSONPath: Query Expressions for JSON). JSONPath defines a syntax
/// for selecting and extracting JSON (RFC 8259) values from within a given
/// JSON value.
///
public indirect enum JSONPath: Codable,
                               Hashable,
                               CustomStringConvertible {
  case `self`
  case current
  case select(JSONPath, Segment)
  
  /// Syntactic sugar for appending a single selector to the JSONPath query `path`.
  public static func children(_ path: JSONPath, _ selector: Selector) -> JSONPath {
    return .select(path, .children([selector]))
  }
  
  /// Syntactic sugar for appending a single descendant to the JSONPath query `path`.
  public static func descendants(_ path: JSONPath, _ selector: Selector) -> JSONPath {
    return .select(path, .descendants([selector]))
  }
  
  /// Creates a `JSONPath` representation of the JSONPath query represented
  /// using the syntax as specified by RFC 9535. An error is thrown if `query`
  /// is not compliant with JSONPath syntax. If parameter `strict` is set to
  /// false, the syntax and semantics of JSONPath are slighly relaxed. For
  /// instance, non-singular queries are supported in query filters.
  public init(query: String, strict: Bool = true) throws {
    var parser = JSONPathParser(string: query, strict: strict)
    self = try parser.parse()
  }
  
  /// Initialize a `JSONPath` reference using a decoder.
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    try self.init(query: try container.decode(String.self))
  }
  
  /// Encode a `JSONPath` reference using the given encoder.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.description)
  }
  
  /// Returns true if this JSONPath value represents a singular query.
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
  
  /// Returns true if this query is a relative JSONPath query, i.e. it does not start
  /// with "$'.
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
  
  /// Returns the sequence of segments of this JSONPath query.
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
  
  /// Returns a `JSONLocation` value matching this JSONPath query. Non-singular queries
  /// cannot be represented as a `JSONLocation` value and thus `nil` gets returned.
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
  
  /// Returns the JSONPath query as a string.
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
  
  /// Representation of JSONPath query segments. There are two different segment types:
  /// children and descendants.
  public enum Segment: Hashable, CustomStringConvertible {
    case children([Selector])
    case descendants([Selector])
    
    /// Returns true if this segment is a descendant segment.
    public var isDescendant: Bool {
      switch self {
        case .children(_):
          return false
        case .descendants(_):
          return true
      }
    }
    
    /// Returns true if this segment is singular, i.e. it refers to at most one value.
    public var isSingular: Bool {
      switch self {
        case .children(let selectors):
          return selectors.count == 1 && selectors[0].isSingular
        case .descendants(_):
          return false
      }
    }
    
    /// Returns the selectors encapsulated by this segment.
    public var selectors: [Selector] {
      switch self {
        case .children(let selectors):
          return selectors
        case .descendants(let selectors):
          return selectors
      }
    }
    
    /// Returns true if this segment can be represented using a shorthand form avoiding
    /// the usage of brackets.
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
    
    /// Returns a string representation of this segment.
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
  
  /// Representation of JSONPath query path selectors. Selectors are either child or
  /// descendant selectors. Supported are:
  ///   - wildcard selectors,
  ///   - member selectors,
  ///   - index selectors,
  ///   - slice selectors, and
  ///   - filter selectors.
  public enum Selector: Hashable, CustomStringConvertible {
    case wildcard
    case member(String)
    case index(Int)
    case slice(Int?, Int?, Int?)
    case filter(Expression)
    
    /// Returns true if this selector is singular, i.e. it refers to at most one value.
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
    
    /// Returns a string representation of this selector when used within a segment
    /// delimited by brackets.
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
  
  /// Representation of JSONPath query filter expressions.
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
    
    /// Return a string representation of this expression if nested within another expression.
    public func description(within context: Expression) -> String {
      switch (self, context) {
        case (.null, _), (.true, _), (.false, _),
             (.integer(_), _), (.float(_), _), (.string(_), _),
             (.variable(_), _), (.query(_), _), (.call(_, _), _):
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
    
    /// Returns a string representation of this expression assuming it is not
    /// embedded in another expression.
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
  
  /// Representation of a unary operator. Supported are currently "-" and "!".
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
  
  /// Representation of a binary operator. Supported are currently "==", "!=", "<",
  /// ">", "<=", ">=", "||", "&&", "+", "-", "*", and "/".
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
}
