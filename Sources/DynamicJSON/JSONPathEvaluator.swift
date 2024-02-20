//
//  JSONPathQueryEvaluator.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 17/02/2024.
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

public struct JSONPathEvaluator {
  let root: JSON
  let env: JSONPathEnvironment
  
  public enum Error: LocalizedError, CustomStringConvertible {
    case booleanNotCoercableToBool
    case doesNotEvaluateToJSON(JSONPath.Expression)
    case cannotNegate(JSONPath.Expression)
    case expectedType(ValueType, JSONPath.Expression)
    case mismatchOfOperandTypes(JSONPath.Expression)
    case divisionByZero(JSONPath.Expression)
    case unknownVariable(String)
    case unknownFunction(String)
    case numberOfArgumentsMismatch(JSONPath.Expression)
    case typeMismatch(String, ValueType, Value)
    case jsonTypeMismatch(String, JSONType, Value)
    
    public var description: String {
      switch self {
        case .booleanNotCoercableToBool:
          return "cannot coerce a boolean to a nodelist"
        case .doesNotEvaluateToJSON(let expr):
          return "expression \(expr) does not evaluate to a JSON value"
        case .cannotNegate(let expr):
          return "cannot negate expression \(expr)"
        case .expectedType(let val, let expr):
          return "expression \(expr) not conforming to expected type \(val)"
        case .mismatchOfOperandTypes(let expr):
          return "operand types of expression \(expr) not matching"
        case .divisionByZero(let expr):
          return "expression \(expr) subject to division by zero"
        case .unknownVariable(let ident):
          return "unknown variable '\(ident)'"
        case .unknownFunction(let ident):
          return "unknown function '\(ident)'"
        case .numberOfArgumentsMismatch(let expr):
          return "mismatch of number of arguments in expression \(expr)"
        case .typeMismatch(let fun, let type, let val):
          return "expected value of type \(type) in function '\(fun), but received \(val)"
        case .jsonTypeMismatch(let fun, let type, let val):
          return "expected JSON value of type \(type) in function '\(fun), but received \(val)"
      }
    }
    
    public var errorDescription: String? {
      return self.description
    }
    
    public var failureReason: String? {
      switch self {
        case .booleanNotCoercableToBool,
             .doesNotEvaluateToJSON(_),
             .cannotNegate(_),
             .expectedType(_, _),
             .mismatchOfOperandTypes(_),
             .typeMismatch(_, _, _),
             .jsonTypeMismatch(_, _, _):
          return "type mismatch"
        case .divisionByZero(_):
          return "division by zero"
        case .unknownVariable(_), .unknownFunction(_):
          return "unknown identifier"
        case .numberOfArgumentsMismatch(_):
          return "number of arguments mismatch"
      }
    }
  }
  
  public struct Function {
    let argtypes: [ValueType]
    let restype: ValueType
    let impl: (JSON, JSON, [Value]) throws -> Value
  }
  
  public enum ValueType: Hashable, CustomStringConvertible {
    case logicalType
    case jsonType
    case nodesType
    
    public var description: String {
      switch self {
        case .logicalType:
          return "Logical"
        case .jsonType:
          return "JSON"
        case .nodesType:
          return "Nodes"
      }
    }
  }
  
  public enum Value: Hashable, CustomStringConvertible {
    case logical(Bool)
    case json(JSON?)
    case nodes([JSON])
    
    init(_ bool: Bool, type: ValueType) throws {
      switch type {
        case .logicalType:
          self = .logical(bool)
        case .jsonType:
          self = .json(.boolean(bool))
        case .nodesType:
          throw Error.booleanNotCoercableToBool
      }
    }
    
    public var isTrue: Bool {
      switch self {
        case .logical(let bool):
          return bool
        default:
          return false
      }
    }
    
    public func has(type: ValueType) -> Bool {
      switch self {
        case .logical(_):
          return type == .logicalType
        case .json(_):
          return type == .jsonType
        case .nodes(_):
          return type == .nodesType
      }
    }
    
    public var description: String {
      switch self {
        case .logical(let bool):
          return bool ? "YES" : "NO"
        case .json(let json):
          if let json {
            return json.description
          } else {
            return "NONE"
          }
        case .nodes(let nodes):
          return "<" + nodes.map { n in n.description }.joined(separator: ", ") + ">"
      }
    }
  }
  
  public init(value: JSON, env: JSONPathEnvironment? = nil) {
    self.root = value
    self.env = env ?? JSONPathEnvironment()
  }
  
  public func query(_ query: JSONPath) throws -> [JSON] {
    return try self.query(current: self.root, with: query)
  }
  
  public func query(current: JSON, with query: JSONPath) throws -> [JSON] {
    switch query {
      case .self:
        return [self.root]
      case .current:
        return [current]
      case .select(let path, let segment):
        return try self.query(current: current, with: path).flatMap { value in
          return try self.select(segment, from: value)
        }
    }
  }
  
  public func select(_ segment: JSONPath.Segment, from value: JSON) throws -> [JSON] {
    switch segment {
      case .children(let selectors):
        return try selectors.flatMap { selector in
          return try self.select(selector, from: value)
        }
      case .descendants(let selectors):
        var result: [JSON] = []
        try value.forEachDescendant { json in
          try result.append(contentsOf: selectors.flatMap { selector in
            return try self.select(selector, from: json)
          })
        }
        return result
    }
  }
  
  public func select(_ selector: JSONPath.Selector, from value: JSON) throws -> [JSON] {
    switch selector {
      case .wildcard:
        switch value {
          case .array(let arr):
            return arr
          case .object(let dict):
            return [JSON](dict.values)
          default:
            return []
        }
      case .member(let name):
        switch value {
          case .object(let dict):
            if let result = dict[name] {
              return [result]
            }
            fallthrough
          default:
            return []
        }
      case .index(let i):
        switch value {
          case .array(let arr):
            let index = i < 0 ? arr.count + i : i
            if arr.indices.contains(index) {
              return [arr[index]]
            }
            fallthrough
          default:
            return []
        }
      case .slice(nil, nil, nil):
        switch value {
          case .array(let arr):
            return arr
          default:
            return []
        }
      case .slice(let s, let e, let inc):
        let step = inc ?? 1
        guard step != 0 else {
          return []
        }
        switch value {
          case .array(let arr):
            func normalize(_ i: Int) -> Int {
              return i >= 0 ? i : arr.count + i
            }
            let start = normalize(s ?? (step >= 0 ? 0 : arr.count - 1))
            let end = normalize(e ?? (step >= 0 ? arr.count : -arr.count - 1))
            let lower = step >= 0 ? min(max(start, 0), arr.count) : min(max(end, -1), arr.count - 1)
            let upper = step >= 0 ? min(max(end, 0), arr.count) : min(max(start, -1), arr.count - 1)
            var result: [JSON] = []
            if step > 0 {
              var i = lower
              while i < upper {
                result.append(arr[i])
                i += step
              }
            } else {
              var i = upper
              while lower < i {
                result.append(arr[i])
                i += step
              }
            }
            return result
          default:
            return []
        }
      case .filter(let expr):
        switch value {
          case .array(let arr):
            var res: [JSON] = []
            for child in arr {
              if try self.evaluate(expr, for: child, expecting: .logicalType).isTrue  {
                res.append(child)
              }
            }
            return res
          case .object(let dict):
            var res: [JSON] = []
            for child in dict.values {
              if try self.evaluate(expr, for: child, expecting: .logicalType).isTrue {
                res.append(child)
              }
            }
            return res
          default:
            return []
        }
    }
  }
  
  public func evaluate(lhs: JSONPath.Expression,
                       rhs: JSONPath.Expression,
                       for value: JSON) throws -> (JSON?, JSON?) {
    guard case .some(.json(let l)) = try? self.evaluate(lhs, for: value, expecting: .jsonType) else {
      throw Error.doesNotEvaluateToJSON(lhs)
    }
    guard case .some(.json(let r)) = try? self.evaluate(rhs, for: value, expecting: .jsonType) else {
      throw Error.doesNotEvaluateToJSON(rhs)
    }
    switch (l, r) {
      case (.some(.integer(let l)), .some(.float(let r))):
        return (.float(Double(l)), .float(r))
      case (.some(.float(let l)), .some(.integer(let r))):
        return (.float(l), .float(Double(r)))
      default:
        return (l, r)
    }
  }
  
  public func evaluate(_ expr: JSONPath.Expression,
                       for value: JSON,
                       expecting type: ValueType) throws -> Value {
    switch expr {
      case .null:
        return .json(.null)
      case .true:
        return .json(.boolean(true))
      case .false:
        return .json(.boolean(false))
      case .integer(let num):
        return .json(.integer(num))
      case .float(let num):
        return .json(.float(num))
      case .string(let str):
        return .json(.string(str))
      case .variable(let ident):
        if let res = self.env.value(of: ident) {
          return res
        } else {
          throw Error.unknownVariable(ident)
        }
      case .query(let path):
        let nodes = try self.query(current: value, with: path)
        switch type {
          case .logicalType:
            return .logical(!nodes.isEmpty)
          case .jsonType:
            throw Error.doesNotEvaluateToJSON(expr)
          case .nodesType:
            return .nodes(nodes)
        }
      case .singularQuery(let path):
        let nodes = try self.query(current: value, with: path)
        switch type {
          case .logicalType:
            return .logical(!nodes.isEmpty)
          case .jsonType:
            return .json(nodes.first)
          case .nodesType:
            return .nodes(nodes)
        }
      case .call(let ident, let arguments):
        guard let function = self.env.function(name: ident) else {
          throw Error.unknownFunction(ident)
        }
        guard function.argtypes.count == arguments.count else {
          throw Error.numberOfArgumentsMismatch(expr)
        }
        var args: [Value] = []
        var i = 0
        while i < arguments.count {
          args.append(try self.evaluate(arguments[i], for: value, expecting: function.argtypes[i]))
          i += 1
        }
        return try function.impl(self.root, value, args)
      case .prefix(let op, let argument):
        switch op {
          case .negate:
            let argres = try self.evaluate(argument, for: value, expecting: .jsonType)
            switch argres {
              case .json(.boolean(let bool)):
                return .json(.boolean(!bool))
              case .json(.integer(let num)):
                return .json(.integer(-num))
              case .json(.float(let num)):
                return .json(.float(-num))
              default:
                throw Error.cannotNegate(argument)
            }
          case .not:
            let argres = try self.evaluate(argument, for: value, expecting: .logicalType)
            switch argres {
              case .logical(let bool):
                return .logical(!bool)
              default:
                throw Error.cannotNegate(argument)
            }
        }
      case .operation(let lhs, let op, let rhs):
        switch op {
          case .equals:
            let (l, r) = try self.evaluate(lhs: lhs, rhs: rhs, for: value)
            return try .init(l == r, type: type)
          case .notEquals:
            let (l, r) = try self.evaluate(lhs: lhs, rhs: rhs, for: value)
            return try .init(l != r, type: type)
          case .lessThan:
            let (l, r) = try self.evaluate(lhs: lhs, rhs: rhs, for: value)
            switch (l, r) {
              case (.boolean(let l), .boolean(let r)):
                return try .init(!l && r, type: type)
              case (.integer(let l), .integer(let r)):
                return try .init(l < r, type: type)
              case (.float(let l), .float(let r)):
                return try .init(l < r, type: type)
              case (.string(let l), .string(let r)):
                return try .init(l.compare(r) == .orderedAscending, type: type)
              default:
                return try .init(false, type: type)
            }
          case .lessThanEquals:
            let (l, r) = try self.evaluate(lhs: lhs, rhs: rhs, for: value)
            switch (l, r) {
              case (nil, nil):
                return try .init(true, type: type)
              case (.null, .null):
                return try .init(true, type: type)
              case (.boolean(let lb), .boolean(let rb)):
                return try .init(!lb && rb || lb == rb, type: type)
              case (.integer(let li), .integer(let ri)):
                return try .init(li <= ri, type: type)
              case (.float(let lf), .float(let rf)):
                return try .init(lf <= rf, type: type)
              case (.string(let l), .string(let r)):
                let res = l.compare(r)
                return try .init(res == .orderedAscending || res == .orderedSame, type: type)
              default:
                return try .init(false, type: type)
            }
          case .greaterThan:
            let (l, r) = try self.evaluate(lhs: lhs, rhs: rhs, for: value)
            switch (l, r) {
              case (.boolean(let lb), .boolean(let rb)):
                return try .init(!rb && lb, type: type)
              case (.integer(let li), .integer(let ri)):
                return try .init(li > ri, type: type)
              case (.float(let lf), .float(let rf)):
                return try .init(lf > rf, type: type)
              case (.string(let l), .string(let r)):
                return try .init(l.compare(r) == .orderedDescending, type: type)
              default:
                return try .init(false, type: type)
            }
          case .greaterThanEquals:
            let (l, r) = try self.evaluate(lhs: lhs, rhs: rhs, for: value)
            switch (l, r) {
              case (nil, nil):
                return try .init(true, type: type)
              case (.null, .null):
                return try .init(true, type: type)
              case (.boolean(let lb), .boolean(let rb)):
                return try .init(!rb && lb || rb == lb, type: type)
              case (.integer(let li), .integer(let ri)):
                return try .init(li >= ri, type: type)
              case (.float(let lf), .float(let rf)):
                return try .init(lf >= rf, type: type)
              case (.string(let l), .string(let r)):
                let res = l.compare(r)
                return try .init(res == .orderedAscending || res == .orderedSame, type: type)
              default:
                return try .init(false, type: type)
            }
          case .or:
            let l = try self.evaluate(lhs, for: value, expecting: type)
            switch l {
              case .logical(let bool):
                guard type == .logicalType else {
                  throw Error.expectedType(type, lhs)
                }
                return bool ? l : try self.evaluate(rhs, for: value, expecting: type)
              case .json(.boolean(let bool)):
                guard type == .jsonType else {
                  throw Error.expectedType(type, lhs)
                }
                return bool ? l : try self.evaluate(rhs, for: value, expecting: type)
              default:
                throw Error.expectedType(type, lhs)
            }
          case .and:
            let l = try self.evaluate(lhs, for: value, expecting: type)
            switch l {
              case .logical(let bool):
                guard type == .logicalType else {
                  throw Error.expectedType(type, lhs)
                }
                return !bool ? l : try self.evaluate(rhs, for: value, expecting: type)
              case .json(.boolean(let bool)):
                guard type == .jsonType else {
                  throw Error.expectedType(type, lhs)
                }
                return !bool ? l : try self.evaluate(rhs, for: value, expecting: type)
              default:
                throw Error.expectedType(type, lhs)
            }
          case .plus:
            let (l, r) = try self.evaluate(lhs: lhs, rhs: rhs, for: value)
            switch (l, r) {
              case (.integer(let l), .integer(let r)):
                return .json(.integer(l &+ r))
              case (.float(let l), .float(let r)):
                return .json(.float(l + r))
              case (.string(let l), .string(let r)):
                return .json(.string(l.appending(r)))
              default:
                throw Error.mismatchOfOperandTypes(expr)
            }
          case .minus:
            let (l, r) = try self.evaluate(lhs: lhs, rhs: rhs, for: value)
            switch (l, r) {
              case (.integer(let l), .integer(let r)):
                return .json(.integer(l &- r))
              case (.float(let l), .float(let r)):
                return .json(.float(l - r))
              default:
                throw Error.mismatchOfOperandTypes(expr)
            }
          case .mult:
            let (l, r) = try self.evaluate(lhs: lhs, rhs: rhs, for: value)
            switch (l, r) {
              case (.integer(let l), .integer(let r)):
                return .json(.integer(l &* r))
              case (.float(let l), .float(let r)):
                return .json(.float(l * r))
              default:
                throw Error.mismatchOfOperandTypes(expr)
            }
          case .divide:
            let (l, r) = try self.evaluate(lhs: lhs, rhs: rhs, for: value)
            switch (l, r) {
              case (.integer(let l), .integer(let r)):
                guard r != 0 else {
                  throw Error.divisionByZero(expr)
                }
                return .json(.integer(l / r))
              case (.float(let l), .float(let r)):
                guard r != 0.0 else {
                  throw Error.divisionByZero(expr)
                }
                return .json(.float(l / r))
              default:
                throw Error.mismatchOfOperandTypes(expr)
            }
        }
    }
  }
}
