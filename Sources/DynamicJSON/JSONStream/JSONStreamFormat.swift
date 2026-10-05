//
//  JSONStreamFormat.swift
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

extension JSON {
  
  ///
  /// The format of a stream of JSON values. A format defines how individual JSON values
  /// are delimited within a sequence of bytes.
  ///
  public enum StreamFormat: Hashable, Sendable {
    
    /// Chooses the format based on the first bytes of the stream: if the first non-whitespace
    /// byte is the ASCII record separator (0x1E), the stream is read as `sequence`; otherwise
    /// as `concatenated`. Since `concatenated` also reads newline-delimited values, this
    /// covers NDJSON/JSON Lines input as well, but does not recover from malformed lines. The
    /// elements of a top-level array are never detected automatically; use `arrayElements`.
    case automatic
    
    /// Newline-delimited JSON, as defined by NDJSON and JSON Lines (`.ndjson`, `.jsonl`). Each
    /// line holds one JSON value. Lines may end with `\r\n`, and blank lines are ignored. After
    /// a malformed line, reading resumes with the next line.
    case lines
    
    /// JSON text sequences as defined by RFC 7464 (`application/json-seq`) and RFC 8142
    /// (`application/geo+json-seq`). Each JSON text is preceded by the ASCII record separator
    /// (0x1E) and typically followed by a line feed. Top-level numbers, `true`, `false`, and
    /// `null` that are not followed by whitespace are considered truncated and are dropped.
    /// After a malformed text, reading resumes with the next record separator.
    case sequence
    
    /// Concatenated JSON: values follow each other with arbitrary (or no) whitespace in between,
    /// e.g. `{"a":1}{"b":2}` or `1 2 3`. Top-level numbers and literals have to be separated by
    /// whitespace from the next value. This format also reads newline-delimited input. The
    /// boundaries of a value are determined by scanning, so after a malformed value, the
    /// remainder of the stream might not be interpreted as intended.
    case concatenated
    
    /// The elements of a single top-level JSON array, `[ v1, v2, ... ]`, are returned one by
    /// one, without having to hold the whole array in memory. Anything but whitespace following
    /// the closing bracket is an error.
    case arrayElements
  }
  
  ///
  /// Determines how errors found in a stream of JSON values are handled.
  ///
  public enum StreamErrorPolicy: Hashable, Sendable {
    
    /// The first error ends the stream. It is thrown by the `for try await` loop that reads
    /// the stream.
    case fail
    
    /// Malformed values are dropped and reading continues, as recommended by RFC 7464.
    /// Errors that make it impossible to continue (see `StreamError.isFatal`) still end the
    /// stream.
    case skipInvalid
  }
  
  ///
  /// Options for reading streams of JSON values.
  ///
  public struct StreamOptions: Hashable, Sendable {
    
    /// How to deal with errors; the default is `StreamErrorPolicy.fail`.
    public var errors: StreamErrorPolicy
    
    /// The maximum size in bytes of a single JSON value. If a value gets larger, the stream
    /// ends with error `StreamError.valueTooLarge`. By default, there is no limit.
    public var maxValueSize: Int?
    
    /// Creates stream options.
    public init(errors: StreamErrorPolicy = .fail, maxValueSize: Int? = nil) {
      self.errors = errors
      self.maxValueSize = maxValueSize
    }
  }
  
  ///
  /// Errors found while reading a stream of JSON values. Each case carries the offset (in
  /// bytes from the beginning of the stream) at which the problem was detected.
  ///
  public enum StreamError: LocalizedError, CustomStringConvertible, Equatable, Sendable {
    case invalidValue(offset: Int, reason: String)
    case truncated(offset: Int)
    case unexpectedByte(UInt8, offset: Int)
    case expectedArray(offset: Int)
    case valueTooLarge(offset: Int)
    
    /// Is it impossible to continue reading the stream after this error?
    public var isFatal: Bool {
      switch self {
        case .expectedArray(_), .valueTooLarge(_):
          return true
        default:
          return false
      }
    }
    
    public var description: String {
      switch self {
        case .invalidValue(let offset, let reason):
          return "invalid JSON value at offset \(offset): \(reason)"
        case .truncated(let offset):
          return "stream ends within a JSON value starting at offset \(offset)"
        case .unexpectedByte(let byte, let offset):
          return "unexpected byte 0x\(String(byte, radix: 16)) at offset \(offset)"
        case .expectedArray(let offset):
          return "expected a top-level JSON array at offset \(offset)"
        case .valueTooLarge(let offset):
          return "JSON value starting at offset \(offset) exceeds the maximum size"
      }
    }
    
    public var errorDescription: String? {
      return self.description
    }
    
    public var failureReason: String? {
      return "stream error"
    }
  }
}
