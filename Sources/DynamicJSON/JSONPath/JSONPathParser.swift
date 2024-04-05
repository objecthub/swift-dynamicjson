//
//  JSONPathParser.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 15/02/2024.
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
/// Parser for JSONPath syntax according to RFC 9535. The parser operates in
/// two different modes: in _strict_ mode, all limitations imposed by RFC 9535
/// are implemented; if _strict_ mode is disabled, there is more flexibility
/// in filter expressions, e.g. also non-singular queries are supported.
///
public struct JSONPathParser {
  
  /// Is strict mode enabled?
  private let strict: Bool
  
  /// Was there trailing space (determined initially)?
  private let trailingSpace: Bool
  
  /// Next character to parse
  private var ch: Character?
  
  /// Remaining characters to parse
  private var iterator: String.Iterator
  
  /// Collection of errors raised by functionality provided by enum `JSONPathParser`.
  public enum Error: LocalizedError, CustomStringConvertible {
    case expectedCharacter(Character, Character?)
    case illegalIntLiteral(String)
    case illegalNumberLiteral(String)
    case expectedStringLiteral(Character?)
    case malformedStringLiteralEscape(String)
    case notASingularQuery(JSONPath)
    case expectedMemberName(Character?)
    case invalidSelectorCharacter(Character?)
    case invalidSegmentCharacter(Character?)
    case emptySegment
    case invalidQueryPrefix
    case invalidQuerySuffix(Character?)
    
    public var description: String {
      switch self {
        case .expectedCharacter(let exp, let found):
          if let found {
            return "expected character \(exp), but found \(found)"
          } else {
            return "expected character \(exp), but reached end of input"
          }
        case .illegalIntLiteral(let str):
          return "cannot parse integer literal from '\(str)'"
        case .illegalNumberLiteral(let str):
          return "cannot parse number literal from '\(str)'"
        case .expectedStringLiteral(let ch):
          if let ch {
            return "expected string literal, but found character '\(ch)'"
          } else {
            return "expected string literal, but reached end of input"
          }
        case .malformedStringLiteralEscape(let str):
          return "string literal escape sequence following '\(str)' is malformed"
        case .notASingularQuery(let path):
          return "not a singular query: \(path)"
        case .expectedMemberName(let ch):
          if let ch {
            return "expected member name, but '\(ch)' is not a valid initial character"
          } else {
            return "expected member name, but reached end of input"
          }
        case .invalidSelectorCharacter(let ch):
          if let ch {
            return "unable to parse selector at character '\(ch)'"
          } else {
            return "invalid selector"
          }
        case .invalidSegmentCharacter(let ch):
          if let ch {
            return "unable to parse segment at character '\(ch)'"
          } else {
            return "invalid segment"
          }
        case .emptySegment:
          return "invalid empty segment"
        case .invalidQueryPrefix:
          return "invalid query start; must start with '$' or '@'"
        case .invalidQuerySuffix(let ch):
          if let ch {
            return "superfluous character '\(ch)' at end of query"
          } else {
            return "superfluous character at end of query"
          }
      }
    }
    
    public var errorDescription: String? {
      return self.description
    }
    
    public var failureReason: String? {
      switch self {
        case .expectedCharacter(_, _):
          return "parsing error"
        case .illegalIntLiteral(_), .illegalNumberLiteral(_):
          return "error parsing integer literal"
        case .expectedStringLiteral(_), .malformedStringLiteralEscape(_):
          return "error parsing string literal"
        case .notASingularQuery(_):
          return "error parsing singular query"
        case .expectedMemberName(_):
          return "error parsing member name"
        case .invalidSelectorCharacter(_):
          return "error parsing selector"
        case .invalidSegmentCharacter(_), .emptySegment:
          return "error parsing segment"
        case .invalidQueryPrefix, .invalidQuerySuffix(_):
          return "error parsing query"
      }
    }
  }
  
  /// Initializes a new parser for parsing `string`. Parser structs can only be used
  /// once for parsing the string given at initialization time.
  public init(string: String, strict: Bool = true) {
    self.strict = strict
    switch string.last {
      case " ", "\t", "\n", "\r":
        self.trailingSpace = true
      default:
        self.trailingSpace = false
    }
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
  private mutating func skipSpacesIfNonStrict() -> Character? {
    guard !self.strict else {
      return self.ch
    }
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
  
  @discardableResult
  private mutating func nextSkipSpacesIfNonStrict() -> Character? {
    self.next()
    return self.skipSpacesIfNonStrict()
  }
  
  private mutating func accept(_ ch: Character) throws {
    if case .some(ch) = self.ch {
      self.next()
    } else {
      throw Error.expectedCharacter(ch, self.ch)
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
    guard let res = Int(num),
          !self.strict || res == 0 || num.first != "0" else {
      throw Error.illegalIntLiteral(num)
    }
    return negative ? -res : res
  }
  
  private mutating func number(forceFloat: Bool = false) throws -> JSONPath.Expression {
    var num = ""
    while self.nextIsDigit {
      num.append(self.ch!)
      self.next()
    }
    if let ch = self.ch, ch == "." {
      num.append(ch)
      self.next()
      guard self.nextIsDigit else {
        throw Error.illegalNumberLiteral(num)
      }
      while self.nextIsDigit {
        num.append(self.ch!)
        self.next()
      }
    } else if forceFloat && num != "0" {
      throw Error.illegalNumberLiteral(num)
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
      throw Error.illegalNumberLiteral(num)
    }
  }
  
  private mutating func string() throws -> String {
    guard let ch = self.ch, ch == "'" || ch == "\"" else {
      throw Error.expectedStringLiteral(self.ch)
    }
    let delimiter = ch
    var str = ""
    var escaped = false
    var lookahead: Character? = nil
    loop: while let nch = lookahead ?? self.next(),
                nch != ch || escaped,
                nch != "\n", nch != "\r" {
      lookahead = nil
      if escaped {
        switch nch {
          case "a":
            str.append("\u{7}")
          case "b":
            str.append("\u{8}")
          case "t":
            str.append("\t")
          case "n":
            str.append("\n")
          case "v":
            str.append("\u{b}")
          case "f":
            str.append("\u{c}")
          case "r":
            str.append("\r")
          case "u":
            var scalars = [UInt16]()
            lookahead = nch
            while lookahead == "u" {
              if let ch0 = self.next(),
                 let ch1 = self.next(),
                 let ch2 = self.next(),
                 let ch3 = self.next(),
                 let num = UInt16("\(ch0)\(ch1)\(ch2)\(ch3)", radix: 16) {
                scalars.append(num)
              } else {
                throw Error.malformedStringLiteralEscape(str)
              }
              if let ch = self.next(), ch == "\\" {
                escaped = true
                lookahead = self.next()
              } else {
                escaped = false
                lookahead = self.ch
                break
              }
            }
            let s: String? = scalars.withUnsafeBufferPointer { ptr in
              if let adr = ptr.baseAddress {
                return String(utf16CodeUnits: adr, count: scalars.count)
              } else {
                return nil
              }
            }
            guard s != nil else {
              throw Error.malformedStringLiteralEscape(str)
            }
            str.append(contentsOf: s!)
            continue loop
          case "/", "\\":
            str.append(nch)
          default:
            guard !self.strict || nch == delimiter else {
              throw Error.malformedStringLiteralEscape(str)
            }
            str.append(nch)
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
  
  private mutating func memberName() throws -> String {
    guard let ch = self.ch else {
      throw Error.expectedMemberName(nil)
    }
    var scalars = ch.unicodeScalars
    guard ch.isLetter
           || ch == "_"
           || scalars.allSatisfy({ c in c.value >= 0x80 && c.value <= 0xD7FF })
           || scalars.allSatisfy({ c in c.value >= 0xE000 && c.value <= 0x10FFFF }) else {
      throw Error.expectedMemberName(ch)
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
  
  private mutating func functionName() throws -> String {
    return try self.memberName()
  }
  
  private mutating func expression() throws -> JSONPath.Expression {
    var exprs: [JSONPath.Expression] = []
    var opers: [JSONPath.BinaryOperator] = []
    func reduce() throws {
      let rhs = exprs.removeLast()
      if self.strict, case .query(let path) = rhs {
        throw Error.notASingularQuery(path)
      }
      let lhs = exprs.removeLast()
      if self.strict, case .query(let path) = lhs {
        throw Error.notASingularQuery(path)
      }
      exprs.append(.operation(lhs, opers.removeLast(), rhs))
    }
    func push(op: JSONPath.BinaryOperator, rhs: JSONPath.Expression) throws {
      while let top = opers.last, top.precedence >= op.precedence {
        try reduce()
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
          try push(op: .equals, rhs: try self.operand())
        case "!":
          self.next()
          try self.accept("=")
          self.skipSpaces()
          try push(op: .notEquals, rhs: try self.operand())
        case "<":
          if let ch = self.next(), ch == "=" {
            self.next()
            self.skipSpaces()
            try push(op: .lessThanEquals, rhs: try self.operand())
          } else {
            self.skipSpaces()
            try push(op: .lessThan, rhs: try self.operand())
          }
        case ">":
          if let ch = self.next(), ch == "=" {
            self.next()
            self.skipSpaces()
            try push(op: .greaterThanEquals, rhs: try self.operand())
          } else {
            self.skipSpaces()
            try push(op: .greaterThan, rhs: try self.operand())
          }
        case "|":
          self.next()
          try self.accept("|")
          self.skipSpaces()
          try push(op: .or, rhs: try self.operand())
        case "&":
          self.next()
          try self.accept("&")
          self.skipSpaces()
          try push(op: .and, rhs: try self.operand())
        case "+":
          self.nextSkipSpaces()
          try push(op: .plus, rhs: try self.operand())
        case "-":
          self.nextSkipSpaces()
          try push(op: .minus, rhs: try self.operand())
        case "*":
          self.nextSkipSpaces()
          try push(op: .mult, rhs: try self.operand())
        case "/":
          self.nextSkipSpaces()
          try push(op: .divide, rhs: try self.operand())
        default:
          break loop
      }
    }
    while !opers.isEmpty {
      try reduce()
    }
    return exprs.removeLast()
  }
  
  private mutating func operand() throws -> JSONPath.Expression {
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
  
  private mutating func atomic() throws -> JSONPath.Expression {
    switch self.ch {
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
      case "1", "2", "3", "4", "5", "6", "7", "8", "9":
        return try self.number()
      case "0":
        guard self.strict else {
          return try self.number()
        }
        if let expr = try? self.number(forceFloat: true) {
          return expr
        }
        fallthrough
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
            if let ch = self.skipSpacesIfNonStrict(), ch == "(" {
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
  
  private mutating func selector() throws -> JSONPath.Selector {
    guard let ch = self.ch else {
      throw Error.invalidSelectorCharacter(nil)
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
          throw Error.invalidSelectorCharacter(self.ch)
        }
      case "?":
        self.nextSkipSpaces()
        let expr = try self.expression()
        return .filter(expr)
      default:
        throw Error.invalidSelectorCharacter(ch)
    }
  }
  
  private mutating func segment() throws -> [JSONPath.Selector] {
    switch self.ch {
      case .none:
        throw Error.invalidSegmentCharacter(self.ch)
      case "*":
        self.next()
        return [.wildcard]
      case "[":
        guard let ch = self.nextSkipSpaces() else {
          throw Error.invalidSegmentCharacter("[")
        }
        guard ch != "]" else {
          self.next()
          guard self.strict else {
            return []
          }
          throw Error.emptySegment
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
  
  private mutating func childSegment() throws -> [JSONPath.Selector] {
    switch self.ch {
      case .none:
        throw Error.invalidSegmentCharacter(self.ch)
      case "*":
        self.next()
        return [.wildcard]
      default:
        return [.member(try self.memberName())]
    }
  }
  
  private mutating func relativePath(to root: JSONPath) throws -> JSONPath {
    var path = root
    while let ch = self.skipSpaces() {
      switch ch {
        case ".":
          if self.nextSkipSpacesIfNonStrict() == "." {
            self.nextSkipSpacesIfNonStrict()
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
  
  private mutating func absolutePath() throws -> JSONPath {
    switch self.ch {
      case "$":
        self.next()
        return try self.relativePath(to: .self)
      case "@":
        self.next()
        return try self.relativePath(to: .current)
      default:
        throw Error.invalidQueryPrefix
    }
  }
  
  /// Parses the string provided in the initializer. Parameter `ignoreRemaining` determines
  /// if trailing whitespace yields an error in strict mode or not.
  public mutating func parse(ignoreRemaining: Bool = false) throws -> JSONPath {
    if !self.strict {
      self.skipSpaces()
    }
    try self.accept("$")
    let res = try self.relativePath(to: .self)
    guard ignoreRemaining
            || (self.strict && self.ch == nil && !self.trailingSpace)
            || (!self.strict && self.skipSpaces() == nil) else {
      throw Error.invalidQuerySuffix(self.ch)
    }
    return res
  }
}
