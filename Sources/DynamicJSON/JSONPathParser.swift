//
//  JSONPathParser.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 15/02/2024.
//

import Foundation

public struct JSONPathParser {
  var ch: Character?
  var iterator: String.Iterator
  
  public init(string: String) {
    self.ch = nil
    self.iterator = string.makeIterator()
    self.next()
  }
  
  @discardableResult
  private mutating func next() -> Character? {
    self.ch = self.iterator.next()
    return self.ch
  }
  
  @discardableResult
  private mutating func skipSpaces() -> Character? {
    while let ch = self.ch {
      switch ch {
        case " ", "\t", "\n", "\r":
          self.next()
        default:
          return ch
      }
    }
    return nil
  }
  
  @discardableResult
  private mutating func nextSkipSpaces() -> Character? {
    self.next()
    return self.skipSpaces()
  }
  
  private mutating func accept(_ ch: Character) throws {
    if case .some(ch) = self.ch {
      self.next()
    } else {
      throw JSONError.invalidKeyPath
    }
  }
  
  private var nextIsDigit: Bool {
    if let ch = self.ch, ch.isASCII, ch.isNumber {
      return true
    } else {
      return false
    }
  }
  
  private mutating func int() throws -> Int {
    var negative = false
    if self.ch == "-" {
      self.next()
      negative = true
    }
    var num = ""
    while self.nextIsDigit {
      num.append(self.ch!)
      self.next()
    }
    guard let res = Int(num) else {
      throw JSONError.invalidKeyPath
    }
    return negative ? -res : res
  }
  
  private mutating func number() throws -> JSONPath.Expression {
    var num = ""
    while self.nextIsDigit {
      num.append(self.ch!)
      self.next()
    }
    if let ch = self.ch, ch == "." {
      num.append(ch)
      self.next()
      while self.nextIsDigit {
        num.append(self.ch!)
        self.next()
      }
    }
    if let ch = self.ch, ch == "e" || ch == "E" {
      num.append(ch)
      if let ch = self.next(), ch == "-" || ch == "+" {
        num.append(ch)
        self.next()
      }
      while self.nextIsDigit {
        num.append(self.ch!)
        self.next()
      }
    }
    if let x = Int64(num) {
      return .integer(x)
    } else if let x = Double(num) {
      return .float(x)
    } else {
      throw JSONError.invalidKeyPath
    }
  }
  
  private mutating func string() throws -> String {
    guard let ch = self.ch, ch == "'" || ch == "\"" else {
      throw JSONError.invalidKeyPath
    }
    var str = ""
    var escaped = false
    while let nch = self.next(), nch != ch || escaped, nch != "\n", nch != "\r" {
      if escaped {
        switch nch {
          case "a": str.append("\u{7}")
          case "b": str.append("\u{8}")
          case "t": str.append("\t")
          case "n": str.append("\n")
          case "v": str.append("\u{11}")
          case "f": str.append("\u{12}")
          case "r": str.append("\r")
          default:  str.append(nch)
        }
        escaped = false
      } else if nch == "\\" {
        escaped = true
      } else {
        str.append(nch)
      }
    }
    try self.accept(ch)
    return str
  }
  
  public mutating func memberName() throws -> String {
    guard let ch = self.ch else {
      throw JSONError.invalidKeyPath
    }
    var scalars = ch.unicodeScalars
    guard ch.isLetter
           || ch == "_"
           || scalars.allSatisfy({ c in c.value >= 0x80 && c.value <= 0xD7FF })
           || scalars.allSatisfy({ c in c.value >= 0xE000 && c.value <= 0x10FFFF }) else {
      throw JSONError.invalidKeyPath
    }
    var member = String(ch)
    while let ch = self.next() {
      scalars = ch.unicodeScalars
      guard ch.isLetter
              || ch.isHexDigit
              || ch == "_"
              || ch == "-"
              || scalars.allSatisfy({ c in c.value >= 0x80 && c.value <= 0xD7FF })
              || scalars.allSatisfy({ c in c.value >= 0xE000 && c.value <= 0x10FFFF }) else {
        return member
      }
      member.append(ch)
    }
    return member
  }
  
  public mutating func functionName() throws -> String {
    return try self.memberName()
  }
  
  public mutating func expression() throws -> JSONPath.Expression {
    var exprs: [JSONPath.Expression] = []
    var opers: [JSONPath.BinaryOperator] = []
    func push(op: JSONPath.BinaryOperator, rhs: JSONPath.Expression) {
      while let top = opers.last, top.precedence >= op.precedence {
        let rhs = exprs.removeLast()
        let lhs = exprs.removeLast()
        opers.removeLast()
        exprs.append(.operation(lhs, top, rhs))
      }
      opers.append(op)
      exprs.append(rhs)
    }
    exprs.append(try self.operand())
    loop: while let ch = self.skipSpaces() {
      switch ch {
        case "=":
          self.next()
          try self.accept("=")
          self.skipSpaces()
          push(op: .equals, rhs: try self.operand())
        case "!":
          self.next()
          try self.accept("=")
          self.skipSpaces()
          push(op: .notEquals, rhs: try self.operand())
        case "<":
          if let ch = self.next(), ch == "=" {
            self.next()
            self.skipSpaces()
            push(op: .lessThanEquals, rhs: try self.operand())
          } else {
            self.skipSpaces()
            push(op: .lessThan, rhs: try self.operand())
          }
        case ">":
          if let ch = self.next(), ch == "=" {
            self.next()
            self.skipSpaces()
            push(op: .greaterThanEquals, rhs: try self.operand())
          } else {
            self.skipSpaces()
            push(op: .greaterThan, rhs: try self.operand())
          }
        case "|":
          self.next()
          try self.accept("|")
          self.skipSpaces()
          push(op: .or, rhs: try self.operand())
        case "&":
          self.next()
          try self.accept("&")
          self.skipSpaces()
          push(op: .and, rhs: try self.operand())
        case "+":
          self.nextSkipSpaces()
          push(op: .plus, rhs: try self.operand())
        case "-":
          self.nextSkipSpaces()
          push(op: .minus, rhs: try self.operand())
        case "*":
          self.nextSkipSpaces()
          push(op: .mult, rhs: try self.operand())
        case "/":
          self.nextSkipSpaces()
          push(op: .divide, rhs: try self.operand())
        default:
          break loop
      }
    }
    while let top = opers.last {
      let rhs = exprs.removeLast()
      let lhs = exprs.removeLast()
      opers.removeLast()
      exprs.append(.operation(lhs, top, rhs))
    }
    return exprs.removeLast()
  }
  
  public mutating func operand() throws -> JSONPath.Expression {
    switch self.ch {
      case "!":
        self.nextSkipSpaces()
        return .prefix(.not, try self.atomic())
      case "-":
        self.nextSkipSpaces()
        let operand = try self.atomic()
        switch operand {
          case .integer(let x):
            return .integer(-x)
          case .float(let x):
            return .float(-x)
          default:
            return .prefix(.negate, operand)
        }
      default:
        return try self.atomic()
    }
  }
  
  public mutating func atomic() throws -> JSONPath.Expression {
    switch self.ch {
      case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
        return try self.number()
      case "'", "\"":
        return .string(try self.string())
      case "$", "@":
        let path = try self.absolutePath()
        return path.isSingular ? .singularQuery(path) : .query(path)
      case "(":
        self.nextSkipSpaces()
        let expr = try self.expression()
        self.skipSpaces()
        try self.accept(")")
        return expr
      default:
        let ident = try self.functionName()
        switch ident {
          case "null":
            return .null
          case "true":
            return .true
          case "false":
            return .false
          default:
            if let ch = self.skipSpaces(), ch == "(" {
              var arguments: [JSONPath.Expression] = []
              if let ch = self.nextSkipSpaces(), ch != ")" {
                arguments.append(try self.expression())
              }
              while let ch = self.skipSpaces(), ch == "," {
                self.nextSkipSpaces()
                arguments.append(try self.expression())
              }
              try self.accept(")")
              return .call(ident, arguments)
            } else {
              return .variable(ident)
            }
        }
    }
  }
  
  public mutating func selector() throws -> JSONPath.Selector {
    guard let ch = self.ch else {
      throw JSONError.invalidKeyPath
    }
    switch ch {
      case "*":
        self.next()
        return .wildcard
      case "'", "\"":
        return .member(try self.string())
      case ":", "-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
        let start: Int? = ch == ":" ? nil : try self.int()
        self.skipSpaces()
        if self.ch == ":" {
          self.nextSkipSpaces()
          let end = self.ch == "-" || self.nextIsDigit ? try self.int() : nil
          self.skipSpaces()
          if self.ch == ":", let ch = self.nextSkipSpaces() {
            let step = ch == "-" || self.nextIsDigit ? try self.int() : nil
            return .slice(start, end, step)
          } else {
            return .slice(start, end, nil)
          }
        } else if let n = start {
          return .index(n)
        } else {
          throw JSONError.invalidKeyPath
        }
      case "?":
        self.nextSkipSpaces()
        let expr = try self.expression()
        return .filter(expr)
      default:
        throw JSONError.invalidKeyPath
    }
  }
  
  public mutating func segment() throws -> [JSONPath.Selector] {
    switch self.ch {
      case .none:
        throw JSONError.invalidKeyPath
      case "*":
        self.next()
        return [.wildcard]
      case "[":
        guard let ch = self.nextSkipSpaces() else {
          throw JSONError.invalidKeyPath
        }
        guard ch != "]" else {
          self.next()
          return []
        }
        var segment: [JSONPath.Selector] = []
        segment.append(try self.selector())
        while let ch = self.skipSpaces(), ch != "]" {
          try self.accept(",")
          self.skipSpaces()
          segment.append(try self.selector())
        }
        try self.accept("]")
        return segment
      default:
        return [.member(try self.memberName())]
    }
  }
  
  public mutating func childSegment() throws -> [JSONPath.Selector] {
    switch self.ch {
      case .none:
        throw JSONError.invalidKeyPath
      case "*":
        self.next()
        return [.wildcard]
      default:
        return [.member(try self.memberName())]
    }
  }
  
  public mutating func relativePath(to root: JSONPath) throws -> JSONPath {
    var path = root
    while let ch = self.skipSpaces() {
      switch ch {
        case ".":
          if self.nextSkipSpaces() == "." {
            self.nextSkipSpaces()
            path = .select(path, .descendants(try self.segment()))
          } else {
            path = .select(path, .children(try self.childSegment()))
          }
        case "[":
          path = .select(path, .children(try self.segment()))
        default:
          return path
      }
    }
    return path
  }
  
  public mutating func absolutePath() throws -> JSONPath {
    switch self.ch {
      case "$":
        self.next()
        return try self.relativePath(to: .self)
      case "@":
        self.next()
        return try self.relativePath(to: .current)
      default:
        throw JSONError.invalidKeyPath
    }
  }
  
  public mutating func parse(ignoreRemaining: Bool = false) throws -> JSONPath {
    self.skipSpaces()
    try self.accept("$")
    let res = try self.relativePath(to: .self)
    guard ignoreRemaining || self.skipSpaces() == nil else {
      throw JSONError.invalidKeyPath
    }
    return res
  }
}
