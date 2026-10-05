//
//  JSONPartialParser.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 04/10/2026.
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
/// A `JSONPartialParser` reads a single JSON value that arrives in fragments of arbitrary
/// size, and provides access to the best available approximation of the value at any time.
/// This is useful for processing structured output and tool calls of large language models,
/// which are streamed as pieces of text that are not valid JSON by themselves.
///
///     var parser = JSONPartialParser()
///     try parser.append(#"{"city": "Par"#)
///     try parser.snapshot()   // {"city": "Par"}
///     try parser.append(#"is", "population": 21"#)
///     try parser.snapshot()   // {"city": "Paris"}
///     try parser.append("00000}")
///     try parser.finish()     // {"city": "Paris", "population": 2100000}
///
/// A snapshot is computed according to the following rules:
///   - Open strings are closed. They contain the text received so far, without incomplete
///     escape sequences and characters. Open arrays and objects are closed.
///   - Object members whose key or value has not been received completely, are omitted. The
///     only exception are strings, which are returned in their partial form.
///   - Numbers are only included once they are followed by a delimiter, because further
///     digits might still arrive. Literals (`true`, `false`, `null`) are included once they
///     are complete.
///
/// As a consequence, each snapshot is a prefix of all later snapshots and of the final value:
/// objects only gain members, arrays only gain elements, and strings only get longer.
///
/// The parser validates the structure of the input as it arrives and throws a
/// `JSON.StreamError` as soon as the input cannot be extended to a valid JSON value. After
/// an error, the parser does not accept any more input.
///
public struct JSONPartialParser {
  private enum Token {
    case none
    case string
    case number
    case literal
  }
  
  private struct Frame {
    let isObject: Bool
    // Arrays: 0 = after `[`, 1 = after a value, 2 = after `,`
    // Objects: 0 = after `{`, 1 = after a key, 2 = after `:`, 3 = after a value, 4 = after `,`
    var state: UInt8
  }
  
  private static let literals: [UInt8: [UInt8]] = [
    UInt8(ascii: "t"): Array("true".utf8),
    UInt8(ascii: "f"): Array("false".utf8),
    UInt8(ascii: "n"): Array("null".utf8)
  ]
  
  private var bytes: [UInt8] = []
  private var stack: [Frame] = []
  private var topDone = false
  private var token: Token = .none
  private var failure: JSON.StreamError? = nil
  
  // Last position at which the received text can be turned into a value by appending closers
  private var cutLength = 0
  private var cutIsObject: [Bool] = []
  
  // State of the string, number, or literal currently being read
  private var tokenStart = 0
  private var stringIsKey = false
  private var safeLength = 0
  private var escapePending = false
  private var unicodeDigits = 0
  private var unicodeValue: UInt32 = 0
  private var utf8Pending = 0
  private var pendingHighSurrogate = false
  private var literal: [UInt8] = []
  private var literalIndex = 0
  
  /// Creates a parser that did not receive any input yet.
  public init() {}
  
  /// The number of bytes received so far.
  public var byteCount: Int {
    return self.bytes.count
  }
  
  /// Returns true if a complete JSON value was received. A top-level number is only
  /// complete after calling `finish()`, since further digits might still arrive.
  public var isComplete: Bool {
    return self.failure == nil && self.topDone && self.token == .none
  }
  
  // MARK: - Input
  
  /// Appends a fragment of text to the input.
  public mutating func append(_ text: String) throws {
    try self.append(contentsOf: text.utf8)
  }
  
  /// Appends a fragment of UTF-8 encoded text to the input. Fragments may end in the middle
  /// of a character.
  public mutating func append<S: Sequence>(contentsOf fragment: S) throws
                                                where S.Element == UInt8 {
    if let failure = self.failure {
      throw failure
    }
    for byte in fragment {
      let pos = self.bytes.count
      self.bytes.append(byte)
      do {
        try self.step(byte, at: pos)
      } catch let error as JSON.StreamError {
        self.failure = error
        throw error
      }
    }
  }
  
  // MARK: - Output
  
  /// Returns the best approximation of the JSON value received so far, or `nil` if not enough
  /// input was received for building a value. Throws an error if the input is malformed
  /// in a way that was not detected by the parser while reading the input (e.g. a lone
  /// surrogate in a string).
  public func snapshot() throws -> JSON? {
    if let failure = self.failure {
      throw failure
    }
    var text: [UInt8]
    var closers: [Bool]
    if self.token == .string && !self.stringIsKey {
      text = Array(self.bytes[0..<self.safeLength])
      text.append(UInt8(ascii: "\""))
      closers = self.stack.map { $0.isObject }
    } else {
      text = Array(self.bytes[0..<self.cutLength])
      closers = self.cutIsObject
    }
    if text.allSatisfy(isJSONWhitespace) {
      return nil
    }
    for isObject in closers.reversed() {
      text.append(isObject ? UInt8(ascii: "}") : UInt8(ascii: "]"))
    }
    do {
      return try JSON(data: Data(text))
    } catch let error {
      throw JSON.StreamError.invalidValue(offset: self.bytes.count,
                                          reason: error.localizedDescription)
    }
  }
  
  /// Signals the end of the input and returns the complete JSON value. Throws
  /// `JSON.StreamError.truncated` if the input ends before the value is complete.
  public mutating func finish() throws -> JSON {
    if let failure = self.failure {
      throw failure
    }
    if self.token == .number {
      try self.endNumber(at: self.bytes.count)
    }
    guard self.token == .none && self.stack.isEmpty && self.topDone else {
      throw JSON.StreamError.truncated(offset: self.bytes.count)
    }
    do {
      return try JSON(data: Data(self.bytes))
    } catch let error {
      throw JSON.StreamError.invalidValue(offset: self.bytes.count,
                                          reason: error.localizedDescription)
    }
  }
  
  // MARK: - Reading bytes
  
  private mutating func step(_ byte: UInt8, at pos: Int) throws {
    switch self.token {
      case .none:
        try self.structural(byte, at: pos)
      case .string:
        try self.stringByte(byte, at: pos)
      case .number:
        if byte == UInt8(ascii: "-") || byte == UInt8(ascii: "+") || byte == UInt8(ascii: ".") ||
           byte == UInt8(ascii: "e") || byte == UInt8(ascii: "E") ||
           (byte >= 0x30 && byte <= 0x39) {
          return
        }
        try self.endNumber(at: pos)
        try self.structural(byte, at: pos)
      case .literal:
        guard byte == self.literal[self.literalIndex] else {
          throw JSON.StreamError.unexpectedByte(byte, offset: pos)
        }
        self.literalIndex += 1
        if self.literalIndex == self.literal.count {
          self.token = .none
          self.valueCompleted(length: pos + 1)
        }
    }
  }
  
  private mutating func structural(_ byte: UInt8, at pos: Int) throws {
    switch byte {
      case 0x20, 0x0A, 0x0D, 0x09:
        break
      case UInt8(ascii: "\""):
        if let frame = self.stack.last, frame.isObject, frame.state == 0 || frame.state == 4 {
          self.beginString(isKey: true, at: pos)
        } else {
          try self.requireValue(byte, at: pos)
          self.beginString(isKey: false, at: pos)
        }
      case UInt8(ascii: "{"), UInt8(ascii: "["):
        try self.requireValue(byte, at: pos)
        self.stack.append(Frame(isObject: byte == UInt8(ascii: "{"), state: 0))
        self.checkpoint(length: pos + 1)
      case UInt8(ascii: "}"), UInt8(ascii: "]"):
        guard let frame = self.stack.last,
              frame.isObject == (byte == UInt8(ascii: "}")),
              frame.state == 0 || (frame.isObject ? frame.state == 3 : frame.state == 1) else {
          throw JSON.StreamError.unexpectedByte(byte, offset: pos)
        }
        self.stack.removeLast()
        self.valueCompleted(length: pos + 1)
      case UInt8(ascii: ","):
        guard let frame = self.stack.last,
              frame.isObject ? frame.state == 3 : frame.state == 1 else {
          throw JSON.StreamError.unexpectedByte(byte, offset: pos)
        }
        self.stack[self.stack.count - 1].state = frame.isObject ? 4 : 2
      case UInt8(ascii: ":"):
        guard let frame = self.stack.last, frame.isObject, frame.state == 1 else {
          throw JSON.StreamError.unexpectedByte(byte, offset: pos)
        }
        self.stack[self.stack.count - 1].state = 2
      case UInt8(ascii: "-"), 0x30...0x39:
        try self.requireValue(byte, at: pos)
        self.token = .number
        self.tokenStart = pos
      case UInt8(ascii: "t"), UInt8(ascii: "f"), UInt8(ascii: "n"):
        try self.requireValue(byte, at: pos)
        self.token = .literal
        self.literal = JSONPartialParser.literals[byte]!
        self.literalIndex = 1
      default:
        throw JSON.StreamError.unexpectedByte(byte, offset: pos)
    }
  }
  
  /// Checks that a value can start at the current position.
  private func requireValue(_ byte: UInt8, at pos: Int) throws {
    let allowed: Bool
    if let frame = self.stack.last {
      allowed = frame.isObject ? frame.state == 2 : (frame.state == 0 || frame.state == 2)
    } else {
      allowed = !self.topDone
    }
    if !allowed {
      throw JSON.StreamError.unexpectedByte(byte, offset: pos)
    }
  }
  
  /// Records that a value ended after `length` bytes.
  private mutating func valueCompleted(length: Int) {
    if let frame = self.stack.last {
      self.stack[self.stack.count - 1].state = frame.isObject ? 3 : 1
    } else {
      self.topDone = true
    }
    self.checkpoint(length: length)
  }
  
  private mutating func checkpoint(length: Int) {
    self.cutLength = length
    self.cutIsObject = self.stack.map { $0.isObject }
  }
  
  // MARK: - Strings and numbers
  
  private mutating func beginString(isKey: Bool, at pos: Int) {
    self.token = .string
    self.stringIsKey = isKey
    self.safeLength = pos + 1
    self.escapePending = false
    self.unicodeDigits = 0
    self.utf8Pending = 0
    self.pendingHighSurrogate = false
  }
  
  private mutating func advanceSafe(to length: Int) {
    self.pendingHighSurrogate = false
    self.safeLength = length
  }
  
  private mutating func stringByte(_ byte: UInt8, at pos: Int) throws {
    if self.utf8Pending > 0 {
      guard byte & 0xC0 == 0x80 else {
        throw JSON.StreamError.invalidValue(offset: pos, reason: "invalid UTF-8 in string")
      }
      self.utf8Pending -= 1
      if self.utf8Pending == 0 {
        self.advanceSafe(to: pos + 1)
      }
      return
    }
    if self.unicodeDigits > 0 {
      let digit: UInt32
      switch byte {
        case 0x30...0x39:
          digit = UInt32(byte - 0x30)
        case UInt8(ascii: "a")...UInt8(ascii: "f"):
          digit = UInt32(byte - UInt8(ascii: "a")) + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"):
          digit = UInt32(byte - UInt8(ascii: "A")) + 10
        default:
          throw JSON.StreamError.unexpectedByte(byte, offset: pos)
      }
      self.unicodeValue = self.unicodeValue * 16 + digit
      self.unicodeDigits -= 1
      if self.unicodeDigits == 0 {
        if self.unicodeValue >= 0xD800 && self.unicodeValue <= 0xDBFF {
          // Wait for the low surrogate
          self.pendingHighSurrogate = true
        } else {
          self.advanceSafe(to: pos + 1)
        }
      }
      return
    }
    if self.escapePending {
      self.escapePending = false
      switch byte {
        case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"), UInt8(ascii: "b"),
             UInt8(ascii: "f"), UInt8(ascii: "n"), UInt8(ascii: "r"), UInt8(ascii: "t"):
          self.advanceSafe(to: pos + 1)
        case UInt8(ascii: "u"):
          self.unicodeDigits = 4
          self.unicodeValue = 0
        default:
          throw JSON.StreamError.unexpectedByte(byte, offset: pos)
      }
      return
    }
    switch byte {
      case UInt8(ascii: "\""):
        self.token = .none
        if self.stringIsKey {
          self.stack[self.stack.count - 1].state = 1
        } else {
          self.valueCompleted(length: pos + 1)
        }
      case UInt8(ascii: "\\"):
        self.escapePending = true
      case 0..<0x20:
        throw JSON.StreamError.unexpectedByte(byte, offset: pos)
      case 0xC2...0xDF:
        self.utf8Pending = 1
      case 0xE0...0xEF:
        self.utf8Pending = 2
      case 0xF0...0xF4:
        self.utf8Pending = 3
      case 0x80...0xFF:
        throw JSON.StreamError.invalidValue(offset: pos, reason: "invalid UTF-8 in string")
      default:
        self.advanceSafe(to: pos + 1)
    }
  }
  
  private mutating func endNumber(at pos: Int) throws {
    guard JSONPartialParser.isValidNumber(self.bytes[self.tokenStart..<pos]) else {
      throw JSON.StreamError.invalidValue(offset: self.tokenStart, reason: "invalid number")
    }
    self.token = .none
    self.valueCompleted(length: pos)
  }
  
  /// Checks the number grammar of RFC 8259: `-? (0 | [1-9][0-9]*) (. [0-9]+)? ([eE] [+-]? [0-9]+)?`
  private static func isValidNumber(_ number: ArraySlice<UInt8>) -> Bool {
    var i = number.startIndex
    let end = number.endIndex
    func digits() -> Int {
      var count = 0
      while i < end && number[i] >= 0x30 && number[i] <= 0x39 {
        i += 1
        count += 1
      }
      return count
    }
    if i < end && number[i] == UInt8(ascii: "-") {
      i += 1
    }
    guard i < end else {
      return false
    }
    if number[i] == 0x30 {
      i += 1
    } else if digits() == 0 {
      return false
    }
    if i < end && number[i] == UInt8(ascii: ".") {
      i += 1
      if digits() == 0 {
        return false
      }
    }
    if i < end && (number[i] == UInt8(ascii: "e") || number[i] == UInt8(ascii: "E")) {
      i += 1
      if i < end && (number[i] == UInt8(ascii: "+") || number[i] == UInt8(ascii: "-")) {
        i += 1
      }
      if digits() == 0 {
        return false
      }
    }
    return i == end
  }
}
