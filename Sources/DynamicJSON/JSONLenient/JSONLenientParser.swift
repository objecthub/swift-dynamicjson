//
//  JSONLenientParser.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 06/10/2026.
//  Copyright © 2026 Matthias Zenger. All rights reserved.
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
/// A tolerant parser for JSON as it is produced by large language models. It accepts the
/// language of JSON with a number of deviations (see `JSONRepair`) and records which of them
/// were needed to make sense of the input. The parser works on UTF-8 bytes in a range of
/// an array and does not use `JSONDecoder`, so it can accept inputs that are not valid JSON.
///
internal struct JSONLenientParser {
  static let maxDepth = 256
  
  private let bytes: [UInt8]
  private let end: Int
  private let repairTruncation: Bool
  private(set) var pos: Int
  private(set) var repairs: Set<JSONRepair> = []
  
  init(bytes: [UInt8], start: Int, end: Int, repairTruncation: Bool) {
    self.bytes = bytes
    self.pos = start
    self.end = end
    self.repairTruncation = repairTruncation
  }
  
  var atEnd: Bool {
    return self.pos >= self.end
  }
  
  // MARK: - Entry points
  
  /// Parses a value starting at the current position (after skipping whitespace and
  /// comments). Returns `nil` if the input ends within the value and `repairTruncation`
  /// is set, but there is nothing to repair (e.g. only a prefix of `true` is available).
  mutating func parseValue(depth: Int = 0) throws -> JSON? {
    guard depth <= JSONLenientParser.maxDepth else {
      throw JSON.LenientError.tooDeeplyNested(offset: self.pos)
    }
    try self.skipTrivia()
    guard self.pos < self.end else {
      throw JSON.LenientError.unexpectedEnd(offset: self.pos)
    }
    let byte = self.bytes[self.pos]
    switch byte {
      case UInt8(ascii: "{"):
        return try self.parseObject(depth: depth)
      case UInt8(ascii: "["):
        return try self.parseArray(depth: depth)
      case UInt8(ascii: "\""), UInt8(ascii: "'"):
        return .string(try self.parseString())
      case UInt8(ascii: "-"), UInt8(ascii: "+"), UInt8(ascii: "."), 0x30...0x39:
        return try self.parseNumber()
      default:
        if JSONLenientParser.isIdentifierStart(byte) {
          return try self.parseLiteral()
        }
        throw JSON.LenientError.unexpectedByte(byte, offset: self.pos)
    }
  }
  
  /// Skips whitespace and comments.
  mutating func skipTrivia() throws {
    while self.pos < self.end {
      let byte = self.bytes[self.pos]
      if isJSONWhitespace(byte) {
        self.pos += 1
      } else if byte == 0xC2 && self.pos + 1 < self.end && self.bytes[self.pos + 1] == 0xA0 {
        // Non-breaking space
        self.pos += 2
      } else if byte == 0xEF && self.pos + 2 < self.end &&
                self.bytes[self.pos + 1] == 0xBB && self.bytes[self.pos + 2] == 0xBF {
        // Byte order mark
        self.pos += 3
      } else if byte == UInt8(ascii: "/") && self.pos + 1 < self.end &&
                self.bytes[self.pos + 1] == UInt8(ascii: "/") {
        self.repairs.insert(.comment)
        while self.pos < self.end && self.bytes[self.pos] != 0x0A {
          self.pos += 1
        }
      } else if byte == UInt8(ascii: "/") && self.pos + 1 < self.end &&
                self.bytes[self.pos + 1] == UInt8(ascii: "*") {
        self.repairs.insert(.comment)
        self.pos += 2
        var closed = false
        while self.pos < self.end {
          if self.bytes[self.pos] == UInt8(ascii: "*") && self.pos + 1 < self.end &&
             self.bytes[self.pos + 1] == UInt8(ascii: "/") {
            self.pos += 2
            closed = true
            break
          }
          self.pos += 1
        }
        if !closed && !self.repairTruncation {
          throw JSON.LenientError.unexpectedEnd(offset: self.pos)
        }
      } else {
        return
      }
    }
  }
  
  // MARK: - Objects and arrays
  
  private mutating func parseObject(depth: Int) throws -> JSON? {
    self.pos += 1
    var members: [String : JSON] = [:]
    var needsSeparator = false
    while true {
      try self.skipTrivia()
      guard self.pos < self.end else {
        return try self.truncated(.object(members))
      }
      let byte = self.bytes[self.pos]
      if byte == UInt8(ascii: "}") {
        self.pos += 1
        return .object(members)
      }
      if byte == UInt8(ascii: ",") {
        guard needsSeparator else {
          throw JSON.LenientError.unexpectedByte(byte, offset: self.pos)
        }
        self.pos += 1
        needsSeparator = false
        try self.skipTrivia()
        if self.pos < self.end && self.bytes[self.pos] == UInt8(ascii: "}") {
          self.repairs.insert(.trailingComma)
        }
        continue
      }
      if needsSeparator {
        // A value is directly followed by the next key: the comma is missing
        guard byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "'") else {
          throw JSON.LenientError.unexpectedByte(byte, offset: self.pos)
        }
        self.repairs.insert(.missingComma)
      }
      guard let key = try self.parseKey() else {
        return try self.truncated(.object(members))
      }
      try self.skipTrivia()
      guard self.pos < self.end else {
        return try self.truncated(.object(members))
      }
      guard self.bytes[self.pos] == UInt8(ascii: ":") else {
        throw JSON.LenientError.unexpectedByte(self.bytes[self.pos], offset: self.pos)
      }
      self.pos += 1
      try self.skipTrivia()
      guard self.pos < self.end else {
        return try self.truncated(.object(members))
      }
      guard let value = try self.parseValue(depth: depth + 1) else {
        return try self.truncated(.object(members))
      }
      members[key] = value
      needsSeparator = true
    }
  }
  
  private mutating func parseKey() throws -> String? {
    let byte = self.bytes[self.pos]
    if byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "'") {
      return try self.parseString()
    }
    guard JSONLenientParser.isIdentifierStart(byte) else {
      throw JSON.LenientError.unexpectedByte(byte, offset: self.pos)
    }
    let start = self.pos
    while self.pos < self.end && JSONLenientParser.isIdentifierPart(self.bytes[self.pos]) {
      self.pos += 1
    }
    self.repairs.insert(.unquotedKey)
    return String(decoding: self.bytes[start..<self.pos], as: UTF8.self)
  }
  
  private mutating func parseArray(depth: Int) throws -> JSON? {
    self.pos += 1
    var elements: [JSON] = []
    var needsSeparator = false
    while true {
      try self.skipTrivia()
      guard self.pos < self.end else {
        return try self.truncated(.array(elements))
      }
      let byte = self.bytes[self.pos]
      if byte == UInt8(ascii: "]") {
        self.pos += 1
        return .array(elements)
      }
      if byte == UInt8(ascii: ",") {
        guard needsSeparator else {
          throw JSON.LenientError.unexpectedByte(byte, offset: self.pos)
        }
        self.pos += 1
        needsSeparator = false
        try self.skipTrivia()
        if self.pos < self.end && self.bytes[self.pos] == UInt8(ascii: "]") {
          self.repairs.insert(.trailingComma)
        }
        continue
      }
      if needsSeparator {
        throw JSON.LenientError.unexpectedByte(byte, offset: self.pos)
      }
      guard let value = try self.parseValue(depth: depth + 1) else {
        return try self.truncated(.array(elements))
      }
      elements.append(value)
      needsSeparator = true
    }
  }
  
  /// Handles the end of the input within an object or array.
  private mutating func truncated(_ value: JSON) throws -> JSON {
    guard self.repairTruncation else {
      throw JSON.LenientError.unexpectedEnd(offset: self.pos)
    }
    self.repairs.insert(.truncated)
    return value
  }
  
  // MARK: - Strings
  
  /// Parses a string enclosed in double or single quotes.
  private mutating func parseString() throws -> String {
    let quote = self.bytes[self.pos]
    if quote == UInt8(ascii: "'") {
      self.repairs.insert(.singleQuotedString)
    }
    self.pos += 1
    var out: [UInt8] = []
    while true {
      guard self.pos < self.end else {
        guard self.repairTruncation else {
          throw JSON.LenientError.unexpectedEnd(offset: self.pos)
        }
        self.repairs.insert(.truncated)
        return String(decoding: out, as: UTF8.self)
      }
      let byte = self.bytes[self.pos]
      self.pos += 1
      if byte == quote {
        return String(decoding: out, as: UTF8.self)
      } else if byte == UInt8(ascii: "\\") {
        guard self.pos < self.end else {
          continue
        }
        try self.parseEscape(into: &out)
      } else {
        if byte < 0x20 {
          self.repairs.insert(.rawControlCharacter)
        }
        out.append(byte)
      }
    }
  }
  
  /// Parses an escape sequence, whose backslash was consumed already.
  private mutating func parseEscape(into out: inout [UInt8]) throws {
    let byte = self.bytes[self.pos]
    self.pos += 1
    switch byte {
      case UInt8(ascii: "n"):
        out.append(0x0A)
      case UInt8(ascii: "t"):
        out.append(0x09)
      case UInt8(ascii: "r"):
        out.append(0x0D)
      case UInt8(ascii: "b"):
        out.append(0x08)
      case UInt8(ascii: "f"):
        out.append(0x0C)
      case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"):
        out.append(byte)
      case UInt8(ascii: "'"):
        out.append(byte)
      case UInt8(ascii: "u"):
        guard var unit = self.parseHex4() else {
          let rest = self.bytes[self.pos..<self.end]
          if rest.count < 4 && rest.allSatisfy({ $0.isHexDigit }) {
            // The input ends within the escape sequence; it is dropped
            self.pos = self.end
            return
          }
          self.repairs.insert(.invalidEscape)
          out.append(byte)
          return
        }
        if unit >= 0xD800 && unit <= 0xDBFF {
          // High surrogate: it needs to be followed by an escaped low surrogate
          let saved = self.pos
          if self.pos + 1 < self.end && self.bytes[self.pos] == UInt8(ascii: "\\") &&
             self.bytes[self.pos + 1] == UInt8(ascii: "u") {
            self.pos += 2
            if let low = self.parseHex4(), low >= 0xDC00 && low <= 0xDFFF {
              unit = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00)
            } else {
              self.pos = saved
              unit = 0xFFFD
            }
          } else if self.pos >= self.end {
            return
          } else {
            unit = 0xFFFD
          }
        } else if unit >= 0xDC00 && unit <= 0xDFFF {
          unit = 0xFFFD
        }
        out.append(contentsOf: Array(String(Character(Unicode.Scalar(unit) ?? "\u{FFFD}")).utf8))
      default:
        // Unknown escape sequences stand for the escaped character
        self.repairs.insert(.invalidEscape)
        out.append(byte)
    }
  }
  
  /// Parses four hexadecimal digits. The position only advances if there are four of them.
  private mutating func parseHex4() -> UInt32? {
    guard self.pos + 4 <= self.end else {
      return nil
    }
    var value: UInt32 = 0
    for i in 0..<4 {
      let byte = self.bytes[self.pos + i]
      let digit: UInt32
      switch byte {
        case 0x30...0x39:
          digit = UInt32(byte - 0x30)
        case UInt8(ascii: "a")...UInt8(ascii: "f"):
          digit = UInt32(byte - UInt8(ascii: "a")) + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"):
          digit = UInt32(byte - UInt8(ascii: "A")) + 10
        default:
          return nil
      }
      value = value * 16 + digit
    }
    self.pos += 4
    return value
  }
  
  // MARK: - Numbers and literals
  
  private static func isIdentifierStart(_ byte: UInt8) -> Bool {
    return (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z")) ||
           (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z")) ||
           byte == UInt8(ascii: "_") || byte == UInt8(ascii: "$")
  }
  
  private static func isIdentifierPart(_ byte: UInt8) -> Bool {
    return self.isIdentifierStart(byte) || (byte >= 0x30 && byte <= 0x39) ||
           byte == UInt8(ascii: "-")
  }
  
  private mutating func parseLiteral() throws -> JSON? {
    let start = self.pos
    while self.pos < self.end && JSONLenientParser.isIdentifierPart(self.bytes[self.pos]) {
      self.pos += 1
    }
    let word = String(decoding: self.bytes[start..<self.pos], as: UTF8.self)
    let value: JSON
    switch word.lowercased() {
      case "true":
        value = .boolean(true)
      case "false":
        value = .boolean(false)
      case "null":
        value = .null
      case "none", "nil", "undefined":
        value = .null
      case "nan", "infinity", "inf":
        // Numbers that are not finite cannot be represented in JSON
        self.repairs.insert(.nonFiniteNumber)
        return .null
      default:
        // The input might end within a literal such as `tru`
        if self.pos >= self.end && self.repairTruncation {
          for literal in ["true", "false", "null"] where literal.hasPrefix(word.lowercased()) {
            self.repairs.insert(.truncated)
            return nil
          }
        }
        throw JSON.LenientError.unexpectedByte(self.bytes[start], offset: start)
    }
    if word != "true" && word != "false" && word != "null" {
      self.repairs.insert(.nonStandardLiteral)
    }
    return value
  }
  
  private mutating func parseNumber() throws -> JSON {
    let start = self.pos
    while self.pos < self.end {
      let byte = self.bytes[self.pos]
      if (byte >= 0x30 && byte <= 0x39) || JSONLenientParser.isIdentifierStart(byte) ||
         byte == UInt8(ascii: "+") || byte == UInt8(ascii: "-") || byte == UInt8(ascii: ".") {
        self.pos += 1
      } else {
        break
      }
    }
    var token = String(decoding: self.bytes[start..<self.pos], as: UTF8.self)
    var negative = false
    if token.hasPrefix("-") {
      negative = true
      token.removeFirst()
    } else if token.hasPrefix("+") {
      self.repairs.insert(.nonStandardNumber)
      token.removeFirst()
    }
    // Numbers that are not finite cannot be represented in JSON
    switch token.lowercased() {
      case "nan", "infinity", "inf":
        self.repairs.insert(.nonFiniteNumber)
        return .null
      default:
        break
    }
    // Hexadecimal integers
    if token.hasPrefix("0x") || token.hasPrefix("0X") {
      guard let value = Int64(token.dropFirst(2), radix: 16) else {
        throw JSON.LenientError.invalidNumber(offset: start)
      }
      self.repairs.insert(.nonStandardNumber)
      return .integer(negative ? -value : value)
    }
    // Normalize into a number that is valid JSON
    var normalized = token
    if normalized.hasPrefix(".") {
      normalized = "0" + normalized
    }
    while normalized.count > 1 && normalized.hasPrefix("0") &&
          normalized[normalized.index(after: normalized.startIndex)].isNumber {
      normalized.removeFirst()
    }
    normalized = normalized.replacingOccurrences(of: ".e", with: ".0e")
                           .replacingOccurrences(of: ".E", with: ".0E")
    if normalized.hasSuffix(".") {
      normalized += "0"
    }
    if normalized != token {
      self.repairs.insert(.nonStandardNumber)
    }
    guard JSONLenientParser.isStrictNumber(Array(normalized.utf8)) else {
      throw JSON.LenientError.invalidNumber(offset: start)
    }
    if let integer = Int64(normalized) {
      return .integer(negative ? -integer : integer)
    }
    let text = negative ? "-" + normalized : normalized
    guard let json = try? JSON(string: text) else {
      throw JSON.LenientError.invalidNumber(offset: start)
    }
    return json
  }
  
  /// Checks the number grammar of RFC 8259 for numbers without sign.
  private static func isStrictNumber(_ number: [UInt8]) -> Bool {
    var i = 0
    func digits() -> Int {
      var count = 0
      while i < number.count && number[i] >= 0x30 && number[i] <= 0x39 {
        i += 1
        count += 1
      }
      return count
    }
    if i < number.count && number[i] == 0x30 {
      i += 1
    } else if digits() == 0 {
      return false
    }
    if i < number.count && number[i] == UInt8(ascii: ".") {
      i += 1
      if digits() == 0 {
        return false
      }
    }
    if i < number.count && (number[i] == UInt8(ascii: "e") || number[i] == UInt8(ascii: "E")) {
      i += 1
      if i < number.count && (number[i] == UInt8(ascii: "+") || number[i] == UInt8(ascii: "-")) {
        i += 1
      }
      if digits() == 0 {
        return false
      }
    }
    return i == number.count
  }
}

extension UInt8 {
  fileprivate var isHexDigit: Bool {
    return (self >= 0x30 && self <= 0x39) ||
           (self >= UInt8(ascii: "a") && self <= UInt8(ascii: "f")) ||
           (self >= UInt8(ascii: "A") && self <= UInt8(ascii: "F"))
  }
}
