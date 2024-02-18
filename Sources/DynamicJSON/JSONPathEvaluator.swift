//
//  JSONPathQueryEvaluator.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 17/02/2024.
//

import Foundation

public struct JSONPathEvaluator {
  let root: JSON
  
  public enum Value: Hashable, CustomStringConvertible {
    case logical(Bool)
    case json(JSON?)
    case nodes([JSON])
    
    public var description: String {
      switch self {
        case .logical(let bool):
          return bool ? "YES" : "NO"
        case .json(let json):
          if let json {
            return json.description
          } else {
            return "NOTHING"
          }
        case .nodes(let nodes):
          return "<" + nodes.map { n in n.description }.joined(separator: ", ") + ">"
      }
    }
  }
  
  public init(value: JSON) {
    self.root = value
  }
  
  public func query(_ query: JSONPath) -> [JSON] {
    return self.query(current: self.root, with: query)
  }
  
  public func query(current: JSON, with query: JSONPath) -> [JSON] {
    switch query {
      case .self:
        return [self.root]
      case .current:
        return [current]
      case .select(let path, let segment):
        return self.query(current: current, with: path).flatMap { value in
          return self.select(segment, from: value)
        }
    }
  }
  
  public func select(_ segment: JSONPath.Segment, from value: JSON) -> [JSON] {
    switch segment {
      case .children(let selectors):
        return selectors.flatMap { selector in
          return self.select(selector, from: value)
        }
      case .descendants(let selectors):
        var result: [JSON] = []
        value.forEachDescendant { json in
          result.append(contentsOf: selectors.flatMap { selector in
            return self.select(selector, from: json)
          })
        }
        return result
    }
  }
  
  public func select(_ selector: JSONPath.Selector, from value: JSON) -> [JSON] {
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
              if self.isTrue(self.evaluate(expr, for: child)) {
                res.append(child)
              }
            }
            return res
          case .object(let dict):
            var res: [JSON] = []
            for child in dict.values {
              if self.isTrue(self.evaluate(expr, for: child)) {
                res.append(child)
              }
            }
            return res
          default:
            return []
        }
    }
  }
  
  private func isTrue(_ value: JSON) -> Bool {
    switch value {
      case .null:
        return false
      case .boolean(let bool):
        return bool
      case .integer(let num):
        return num != 0
      case .float(let num):
        return num != 0.0
      case .string(let str):
        return !str.isEmpty
      case .array(let arr):
        return !arr.isEmpty
      case .object(let dict):
        return !dict.isEmpty
    }
  }
  
  public func coerce(lhs: JSON, rhs: JSON) -> (JSON, JSON) {
    switch (lhs, rhs) {
      case (.integer(let l), .float(let r)):
        return (.float(Double(l)), .float(r))
      case (.float(let l), .integer(let r)):
        return (.float(l), .float(Double(r)))
      case (.array(let arr), .integer(_)),
           (.array(let arr), .float(_)),
           (.array(let arr), .boolean(_)),
           (.array(let arr), .string(_)),
           (.array(let arr), .null):
        if arr.count == 1 {
          return self.coerce(lhs: arr[0], rhs: rhs)
        }
        return (lhs, rhs)
      case (.integer(_), .array(let arr)),
           (.float(_), .array(let arr)),
           (.boolean(_), .array(let arr)),
           (.string(_), .array(let arr)),
           (.null, .array(let arr)):
        if arr.count == 1 {
          return self.coerce(lhs: lhs, rhs: arr[0])
        }
        fallthrough
      default:
        return (lhs, rhs)
    }
  }
  
  public func evaluate(_ expr: JSONPath.Expression, for value: JSON) -> JSON {
    switch expr {
      case .null:
        return .null
      case .true:
        return .boolean(true)
      case .false:
        return .boolean(false)
      case .integer(let num):
        return .integer(num)
      case .float(let num):
        return .float(num)
      case .string(let str):
        return .string(str)
      case .variable(let ident):
        return .null // TODO
      case .query(let path), .singularQuery(let path):
        let arr = self.query(current: value, with: path)
        if arr.isEmpty {
          return .null
        } else {
          return .array(arr)
        }
      case .call(let ident, let arguments):
        return .null // TODO
      case .prefix(let op, let argument):
        let argres = self.evaluate(argument, for: value)
        switch op {
          case .negate:
            switch argres {
              case .boolean(let bool):
                return .boolean(!bool)
              case .integer(let num):
                return .integer(-num)
              case .float(let num):
                return .float(-num)
              case .null, .string(_), .array(_), .object(_):
                return .null
            }
          case .not:
            return .boolean(!self.isTrue(argres))
        }
      case .operation(let lhs, let op, let rhs):
        switch op {
          case .equals:
            let (l, r) = self.coerce(lhs: self.evaluate(lhs, for: value),
                                     rhs: self.evaluate(rhs, for: value))
            return .boolean(l == r)
          case .notEquals:
            let (l, r) = self.coerce(lhs: self.evaluate(lhs, for: value),
                                     rhs: self.evaluate(rhs, for: value))
            return .boolean(l != r)
          case .lessThan:
            switch self.coerce(lhs: self.evaluate(lhs, for: value),
                               rhs: self.evaluate(rhs, for: value)) {
              case (.boolean(let l), .boolean(let r)):
                return .boolean(!l && r)
              case (.integer(let l), .integer(let r)):
                return .boolean(l < r)
              case (.float(let l), .float(let r)):
                return .boolean(l < r)
              case (.string(let l), .string(let r)):
                return .boolean(l.compare(r) == .orderedAscending)
              default:
                return .boolean(false)
            }
          case .lessThanEquals:
            switch self.coerce(lhs: self.evaluate(lhs, for: value),
                               rhs: self.evaluate(rhs, for: value)) {
              case (.null, .null):
                return true
              case (.boolean(let lb), .boolean(let rb)):
                return .boolean(!lb && rb || lb == rb)
              case (.integer(let li), .integer(let ri)):
                return .boolean(li <= ri)
              case (.float(let lf), .float(let rf)):
                return .boolean(lf <= rf)
              case (.string(let l), .string(let r)):
                let res = l.compare(r)
                return .boolean(res == .orderedAscending || res == .orderedSame)
              default:
                return .boolean(false)
            }
          case .greaterThan:
            switch self.coerce(lhs: self.evaluate(lhs, for: value),
                               rhs: self.evaluate(rhs, for: value)) {
              case (.boolean(let lb), .boolean(let rb)):
                return .boolean(!rb && lb)
              case (.integer(let li), .integer(let ri)):
                return .boolean(li > ri)
              case (.float(let lf), .float(let rf)):
                return .boolean(lf > rf)
              case (.string(let l), .string(let r)):
                return .boolean(l.compare(r) == .orderedDescending)
              default:
                return .boolean(false)
            }
          case .greaterThanEquals:
            switch self.coerce(lhs: self.evaluate(lhs, for: value),
                               rhs: self.evaluate(rhs, for: value)) {
              case (.null, .null):
                return true
              case (.boolean(let lb), .boolean(let rb)):
                return .boolean(!rb && lb || rb == lb)
              case (.integer(let li), .integer(let ri)):
                return .boolean(li >= ri)
              case (.float(let lf), .float(let rf)):
                return .boolean(lf >= rf)
              case (.string(let l), .string(let r)):
                let res = l.compare(r)
                return .boolean(res == .orderedAscending || res == .orderedSame)
              default:
                return .boolean(false)
            }
          case .or:
            let lhsres = self.evaluate(lhs, for: value)
            return self.isTrue(lhsres) ? lhsres : self.evaluate(rhs, for: value)
          case .and:
            let lhsres = self.evaluate(lhs, for: value)
            return !self.isTrue(lhsres) ? lhsres : self.evaluate(rhs, for: value)
          case .plus:
            switch self.coerce(lhs: self.evaluate(lhs, for: value),
                               rhs: self.evaluate(rhs, for: value)) {
              case (.integer(let l), .integer(let r)):
                return .integer(l &+ r)
              case (.float(let l), .float(let r)):
                return .float(l + r)
              case (.string(let l), .string(let r)):
                return .string(l.appending(r))
              default:
                return .null
            }
          case .minus:
            switch self.coerce(lhs: self.evaluate(lhs, for: value),
                               rhs: self.evaluate(rhs, for: value)) {
              case (.integer(let l), .integer(let r)):
                return .integer(l &- r)
              case (.float(let l), .float(let r)):
                return .float(l - r)
              default:
                return .null
            }
          case .mult:
            switch self.coerce(lhs: self.evaluate(lhs, for: value),
                               rhs: self.evaluate(rhs, for: value)) {
              case (.integer(let l), .integer(let r)):
                return .integer(l &* r)
              case (.float(let l), .float(let r)):
                return .float(l * r)
              default:
                return .null
            }
          case .divide:
            switch self.coerce(lhs: self.evaluate(lhs, for: value),
                               rhs: self.evaluate(rhs, for: value)) {
              case (.integer(let l), .integer(let r)):
                return r == 0 ? .null : .integer(l / r)
              case (.float(let l), .float(let r)):
                return r == 0.0 ? .null : .float(l / r)
              default:
                return .null
            }
        }
    }
  }
}
