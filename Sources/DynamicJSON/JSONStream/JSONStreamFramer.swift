//
//  JSONStreamFramer.swift
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

/// Returns true for the four whitespace bytes allowed by JSON.
@inline(__always)
internal func isJSONWhitespace(_ byte: UInt8) -> Bool {
  return byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09
}

///
/// A `ValueScanner` finds the boundaries of a single JSON value within a sequence of bytes
/// without parsing it. It tracks nesting depth and string state to find the end of objects,
/// arrays, and strings. Top-level numbers and literals end at a byte for which the
/// `scalarEnds` predicate holds.
///
internal struct ValueScanner {
  enum State {
    case idle
    case container
    case string
    case scalar
  }
  
  enum Outcome {
    /// The byte was consumed; the value is incomplete.
    case more
    /// The byte was consumed; the value is complete and available via `take()`.
    case done
    /// The byte was not consumed; the value is complete and available via `take()`.
    case doneReprocess
    /// The byte cannot start a value.
    case unexpected
  }
  
  private(set) var state: State = .idle
  private(set) var buffer: [UInt8] = []
  private(set) var start: Int = 0
  private var depth = 0
  private var inString = false
  private var escaped = false
  
  var isIdle: Bool {
    return self.state == .idle
  }
  
  var size: Int {
    return self.buffer.count
  }
  
  mutating func push(_ byte: UInt8, at pos: Int, scalarEnds: (UInt8) -> Bool) -> Outcome {
    switch self.state {
      case .idle:
        if isJSONWhitespace(byte) {
          return .more
        }
        switch byte {
          case UInt8(ascii: "{"), UInt8(ascii: "["):
            self.begin(.container, byte, pos)
            self.depth = 1
            self.inString = false
            self.escaped = false
          case UInt8(ascii: "\""):
            self.begin(.string, byte, pos)
            self.escaped = false
          case UInt8(ascii: "}"), UInt8(ascii: "]"), UInt8(ascii: ","), UInt8(ascii: ":"):
            return .unexpected
          default:
            self.begin(.scalar, byte, pos)
        }
        return .more
      case .container:
        self.buffer.append(byte)
        if self.inString {
          self.stringByte(byte)
          return .more
        }
        switch byte {
          case UInt8(ascii: "\""):
            self.inString = true
            self.escaped = false
          case UInt8(ascii: "{"), UInt8(ascii: "["):
            self.depth += 1
          case UInt8(ascii: "}"), UInt8(ascii: "]"):
            self.depth -= 1
            if self.depth == 0 {
              self.state = .idle
              return .done
            }
          default:
            break
        }
        return .more
      case .string:
        self.buffer.append(byte)
        if self.escaped {
          self.escaped = false
        } else if byte == UInt8(ascii: "\\") {
          self.escaped = true
        } else if byte == UInt8(ascii: "\"") {
          self.state = .idle
          return .done
        }
        return .more
      case .scalar:
        if scalarEnds(byte) {
          self.state = .idle
          return .doneReprocess
        }
        self.buffer.append(byte)
        return .more
    }
  }
  
  /// Returns the completed value and resets the scanner.
  mutating func take() -> [UInt8] {
    let res = self.buffer
    self.buffer.removeAll(keepingCapacity: true)
    return res
  }
  
  /// Called at the end of the stream. Returns the pending scalar, if there is one.
  mutating func finishScalar() -> [UInt8]? {
    guard self.state == .scalar else {
      return nil
    }
    self.state = .idle
    return self.take()
  }
  
  private mutating func begin(_ state: State, _ byte: UInt8, _ pos: Int) {
    self.state = state
    self.buffer.removeAll(keepingCapacity: true)
    self.buffer.append(byte)
    self.start = pos
  }
  
  private mutating func stringByte(_ byte: UInt8) {
    if self.escaped {
      self.escaped = false
    } else if byte == UInt8(ascii: "\\") {
      self.escaped = true
    } else if byte == UInt8(ascii: "\"") {
      self.inString = false
    }
  }
}

///
/// A `JSONStreamFramer` splits a sequence of bytes into frames, each containing the bytes of
/// one JSON text, according to a `JSON.StreamFormat`. Frames are not parsed. The framer is
/// a push-based state machine; bytes can be provided in chunks of arbitrary size.
///
internal struct JSONStreamFramer {
  enum Event {
    case frame([UInt8], offset: Int)
    case error(JSON.StreamError)
  }
  
  private enum Mode {
    case undetermined
    case lines
    case sequence
    case concatenated
    case array
  }
  
  private enum ArrayState {
    case expectOpen
    case wantFirst
    case wantNext
    case afterValue
    case closed
  }
  
  private static let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
  private static let recordSeparator: UInt8 = 0x1E
  
  private var mode: Mode
  private let maxSize: Int?
  private var offset = 0
  private var bomMatched = 0
  private var atStart = true
  private var halted = false
  private var record: [UInt8] = []
  private var recordStart = 0
  private var scanner = ValueScanner()
  private var arrayState: ArrayState = .expectOpen
  
  init(format: JSON.StreamFormat, maxValueSize: Int?) {
    self.maxSize = maxValueSize
    switch format {
      case .automatic:
        self.mode = .undetermined
      case .lines:
        self.mode = .lines
      case .sequence:
        self.mode = .sequence
      case .concatenated:
        self.mode = .concatenated
      case .arrayElements:
        self.mode = .array
    }
  }
  
  // MARK: - Public interface
  
  /// Processes the next byte of the stream, appending any resulting events.
  mutating func push(_ byte: UInt8, into events: inout [Event]) {
    guard !self.halted else {
      return
    }
    let pos = self.offset
    self.offset += 1
    if self.atStart {
      if self.bomMatched < 3 && byte == JSONStreamFramer.bom[self.bomMatched] {
        self.bomMatched += 1
        if self.bomMatched == 3 {
          self.atStart = false
        }
        return
      }
      self.atStart = false
      let replay = JSONStreamFramer.bom[0..<self.bomMatched]
      self.bomMatched = 0
      for (i, b) in replay.enumerated() {
        self.process(b, at: pos - replay.count + i, into: &events)
      }
    }
    self.process(byte, at: pos, into: &events)
  }
  
  /// Signals the end of the stream, appending any resulting events.
  mutating func finish(into events: inout [Event]) {
    guard !self.halted else {
      return
    }
    if self.atStart && self.bomMatched > 0 {
      self.atStart = false
      let replay = JSONStreamFramer.bom[0..<self.bomMatched]
      self.bomMatched = 0
      for (i, b) in replay.enumerated() {
        self.process(b, at: self.offset - replay.count + i, into: &events)
      }
    }
    switch self.mode {
      case .undetermined:
        break
      case .lines:
        self.endLine(into: &events)
      case .sequence:
        self.endRecord(into: &events)
      case .concatenated:
        self.finishScanner(into: &events)
      case .array:
        if self.arrayState != .expectOpen && self.arrayState != .closed {
          events.append(.error(.truncated(offset: self.offset)))
        }
    }
    self.halted = true
  }
  
  // MARK: - Byte processing
  
  private mutating func process(_ byte: UInt8, at pos: Int, into events: inout [Event]) {
    if self.mode == .undetermined {
      if byte == JSONStreamFramer.recordSeparator {
        self.mode = .sequence
      } else if isJSONWhitespace(byte) {
        return
      } else {
        self.mode = .concatenated
      }
    }
    switch self.mode {
      case .undetermined:
        break
      case .lines:
        self.processLine(byte, at: pos, into: &events)
      case .sequence:
        self.processSequence(byte, at: pos, into: &events)
      case .concatenated:
        self.processConcatenated(byte, at: pos, into: &events)
      case .array:
        self.processArray(byte, at: pos, into: &events)
    }
  }
  
  private mutating func fail(_ error: JSON.StreamError, into events: inout [Event]) {
    events.append(.error(error))
    if error.isFatal {
      self.halted = true
    }
  }
  
  private mutating func emit(_ frame: [UInt8], offset: Int, into events: inout [Event]) {
    events.append(.frame(frame, offset: offset))
  }
  
  // MARK: - Lines and sequences (record-based formats)
  
  private mutating func append(record byte: UInt8, at pos: Int, into events: inout [Event]) {
    if self.record.isEmpty {
      self.recordStart = pos
    }
    self.record.append(byte)
    if let max = self.maxSize, self.record.count > max {
      self.fail(.valueTooLarge(offset: self.recordStart), into: &events)
    }
  }
  
  private mutating func processLine(_ byte: UInt8, at pos: Int, into events: inout [Event]) {
    if byte == 0x0A {
      self.endLine(into: &events)
    } else {
      self.append(record: byte, at: pos, into: &events)
    }
  }
  
  private mutating func endLine(into events: inout [Event]) {
    if self.record.last == 0x0D {
      self.record.removeLast()
    }
    if !self.record.allSatisfy(isJSONWhitespace) {
      self.emit(self.record, offset: self.recordStart, into: &events)
    }
    self.record.removeAll(keepingCapacity: true)
  }
  
  private mutating func processSequence(_ byte: UInt8, at pos: Int, into events: inout [Event]) {
    if byte == JSONStreamFramer.recordSeparator {
      self.endRecord(into: &events)
    } else {
      self.append(record: byte, at: pos, into: &events)
    }
  }
  
  private mutating func endRecord(into events: inout [Event]) {
    defer {
      self.record.removeAll(keepingCapacity: true)
    }
    guard let first = self.record.first(where: { !isJSONWhitespace($0) }) else {
      return
    }
    switch first {
      case UInt8(ascii: "{"), UInt8(ascii: "["), UInt8(ascii: "\""):
        break
      default:
        // A top-level number or literal needs to be followed by whitespace. Otherwise, it
        // might have been truncated and needs to be dropped (see RFC 7464, section 2.4).
        guard let last = self.record.last, isJSONWhitespace(last) else {
          return
        }
    }
    self.emit(self.record, offset: self.recordStart, into: &events)
  }
  
  // MARK: - Concatenated values
  
  private static func endsScalarInSequence(_ byte: UInt8) -> Bool {
    return isJSONWhitespace(byte) ||
           byte == UInt8(ascii: "{") ||
           byte == UInt8(ascii: "[") ||
           byte == UInt8(ascii: "\"")
  }
  
  private mutating func processConcatenated(_ byte: UInt8,
                                            at pos: Int,
                                            into events: inout [Event]) {
    switch self.scanner.push(byte, at: pos, scalarEnds: Self.endsScalarInSequence) {
      case .more:
        self.checkScannerSize(into: &events)
      case .done:
        if !self.checkScannerSize(into: &events) {
          return
        }
        self.emit(self.scanner.take(), offset: self.scanner.start, into: &events)
      case .doneReprocess:
        self.emit(self.scanner.take(), offset: self.scanner.start, into: &events)
        self.processConcatenated(byte, at: pos, into: &events)
      case .unexpected:
        self.fail(.unexpectedByte(byte, offset: pos), into: &events)
    }
  }
  
  /// Checks that the value being scanned does not exceed the maximum size. Returns false (and
  /// records an error) if it does.
  @discardableResult
  private mutating func checkScannerSize(into events: inout [Event]) -> Bool {
    if let max = self.maxSize, self.scanner.size > max {
      self.fail(.valueTooLarge(offset: self.scanner.start), into: &events)
      return false
    }
    return true
  }
  
  private mutating func finishScanner(into events: inout [Event]) {
    switch self.scanner.state {
      case .idle:
        break
      case .scalar:
        let start = self.scanner.start
        if let frame = self.scanner.finishScalar() {
          self.emit(frame, offset: start, into: &events)
        }
      case .container, .string:
        events.append(.error(.truncated(offset: self.scanner.start)))
    }
  }
  
  // MARK: - Elements of a top-level array
  
  private static func endsScalarInArray(_ byte: UInt8) -> Bool {
    return isJSONWhitespace(byte) || byte == UInt8(ascii: ",") || byte == UInt8(ascii: "]")
  }
  
  private mutating func processArray(_ byte: UInt8, at pos: Int, into events: inout [Event]) {
    switch self.arrayState {
      case .expectOpen:
        if isJSONWhitespace(byte) {
          return
        }
        if byte == UInt8(ascii: "[") {
          self.arrayState = .wantFirst
        } else {
          self.fail(.expectedArray(offset: pos), into: &events)
        }
      case .wantFirst, .wantNext:
        if self.scanner.isIdle {
          if byte == UInt8(ascii: "]") && self.arrayState == .wantFirst {
            self.arrayState = .closed
            return
          } else if byte == UInt8(ascii: "]") || byte == UInt8(ascii: ",") {
            self.fail(.unexpectedByte(byte, offset: pos), into: &events)
            return
          }
        }
        switch self.scanner.push(byte, at: pos, scalarEnds: Self.endsScalarInArray) {
          case .more:
            self.checkScannerSize(into: &events)
          case .done:
            if !self.checkScannerSize(into: &events) {
              return
            }
            self.emit(self.scanner.take(), offset: self.scanner.start, into: &events)
            self.arrayState = .afterValue
          case .doneReprocess:
            self.emit(self.scanner.take(), offset: self.scanner.start, into: &events)
            self.arrayState = .afterValue
            self.processArray(byte, at: pos, into: &events)
          case .unexpected:
            self.fail(.unexpectedByte(byte, offset: pos), into: &events)
        }
      case .afterValue:
        if isJSONWhitespace(byte) {
          return
        }
        switch byte {
          case UInt8(ascii: ","):
            self.arrayState = .wantNext
          case UInt8(ascii: "]"):
            self.arrayState = .closed
          default:
            self.fail(.unexpectedByte(byte, offset: pos), into: &events)
        }
      case .closed:
        if !isJSONWhitespace(byte) {
          self.fail(.unexpectedByte(byte, offset: pos), into: &events)
        }
    }
  }
}

///
/// A `JSONStreamCore` connects a framer with the JSON decoder. Bytes are pushed in; decoded
/// values or errors are polled out.
///
internal struct JSONStreamCore {
  private var framer: JSONStreamFramer
  private var pending: [JSONStreamFramer.Event] = []
  private var head = 0
  private(set) var isFinished = false
  private(set) var isHalted = false
  
  init(format: JSON.StreamFormat, options: JSON.StreamOptions) {
    self.framer = JSONStreamFramer(format: format, maxValueSize: options.maxValueSize)
  }
  
  /// Is the stream completely processed, i.e. no further results can be polled?
  var isDone: Bool {
    return self.isHalted || (self.isFinished && self.head >= self.pending.count)
  }
  
  mutating func push(_ byte: UInt8) {
    self.framer.push(byte, into: &self.pending)
  }
  
  mutating func finish() {
    if !self.isFinished {
      self.isFinished = true
      self.framer.finish(into: &self.pending)
    }
  }
  
  mutating func halt() {
    self.isHalted = true
  }
  
  /// Returns the next decoded value or error, if there is one available.
  mutating func poll() -> Result<JSON, JSON.StreamError>? {
    guard !self.isHalted else {
      return nil
    }
    guard self.head < self.pending.count else {
      self.pending.removeAll(keepingCapacity: true)
      self.head = 0
      return nil
    }
    let event = self.pending[self.head]
    self.head += 1
    switch event {
      case .frame(let bytes, let offset):
        do {
          return .success(try JSON(data: Data(bytes)))
        } catch let error {
          return .failure(.invalidValue(offset: offset, reason: error.localizedDescription))
        }
      case .error(let error):
        if error.isFatal {
          self.isHalted = true
        }
        return .failure(error)
    }
  }
}
