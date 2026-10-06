//
//  JSONStreamWriter.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 07/10/2026.
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
  /// The line ending used by writers for formats that are based on lines.
  ///
  public enum LineEnding: Hashable, Sendable {
    
    /// A line feed (`\n`).
    case lf
    
    /// A carriage return followed by a line feed (`\r\n`).
    case crlf
    
    /// The bytes of this line ending.
    public var string: String {
      switch self {
        case .lf:
          return "\n"
        case .crlf:
          return "\r\n"
      }
    }
  }
  
  ///
  /// Options for writing streams of JSON values. Most of them correspond to parameters of
  /// `JSON.data(formatting:dateEncodingStrategy:floatEncodingStrategy:userInfo:)`.
  ///
  public struct StreamWriteOptions: Sendable {
    
    /// The format of the encoded values. By default, slashes are not escaped. Add
    /// `.sortedKeys` for output that is stable from run to run. Format `lines` always writes
    /// compact JSON, so `.prettyPrinted` is ignored for it.
    public var formatting: JSONEncoder.OutputFormatting
    
    /// How floating-point values that are not finite (NaN, infinity) are encoded. By default,
    /// writing them fails, as JSON cannot represent them.
    public var floatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy
    
    /// How dates are encoded. This only matters for values of types that contain dates, which
    /// are written directly with `JSONStreamWriter.write(_:)`.
    public var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy
    
    /// User info that is provided to the encoder of `Encodable` values.
    public var userInfo: [CodingUserInfoKey : any Sendable]?
    
    /// The line ending of the formats `lines` and `serverSentEvents`. The default is a
    /// line feed. (Format `sequence` always uses a line feed, as required by RFC 7464.)
    public var lineEnding: LineEnding
    
    /// The text written after each value of format `concatenated`. It may only consist of
    /// JSON whitespace. A space is added after top-level numbers, `true`, `false`, and `null`
    /// if the separator does not start with whitespace, since these values are not self-delimiting.
    public var separator: String
    
    /// For format `serverSentEvents`: the data of a last event that is written when
    /// the writer is finished, e.g. `[DONE]` as used by the OpenAI API. By default, no such
    /// event is written.
    public var terminator: String?
    
    /// Creates options for writing streams.
    public init(formatting: JSONEncoder.OutputFormatting = [.withoutEscapingSlashes],
                floatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy = .throw,
                dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
                userInfo: [CodingUserInfoKey : any Sendable]? = nil,
                lineEnding: LineEnding = .lf,
                separator: String = "\n",
                terminator: String? = nil) {
      self.formatting = formatting
      self.floatEncodingStrategy = floatEncodingStrategy
      self.dateEncodingStrategy = dateEncodingStrategy
      self.userInfo = userInfo
      self.lineEnding = lineEnding
      self.separator = separator
      self.terminator = terminator
    }
  }
  
  ///
  /// Errors found while writing a stream of JSON values.
  ///
  public enum StreamWriteError: LocalizedError, CustomStringConvertible, Equatable, Sendable {
    
    /// The format cannot be used for writing, e.g. `StreamFormat.automatic`.
    case unsupportedFormat(StreamFormat)
    
    /// The operation is not available for the format of the writer.
    case unsupportedOperation(String)
    
    /// The separator of format `concatenated` contains characters that are not JSON whitespace.
    case invalidSeparator
    
    /// The writer was finished already.
    case finished
    
    /// A value could not be encoded.
    case encoding(String)
    
    public var description: String {
      switch self {
        case .unsupportedFormat(let format):
          return "format \(format) cannot be used for writing; specify the format explicitly"
        case .unsupportedOperation(let name):
          return "\(name) is not supported by the format of this writer"
        case .invalidSeparator:
          return "the separator may only consist of whitespace"
        case .finished:
          return "the writer was finished already"
        case .encoding(let reason):
          return "unable to encode value: \(reason)"
      }
    }
    
    public var errorDescription: String? {
      return self.description
    }
    
    public var failureReason: String? {
      return "stream writing error"
    }
  }
}

///
/// A `JSONStreamWriter` turns JSON values into the bytes of a stream in one of the formats
/// of `JSON.StreamFormat`; it is the counterpart of `JSON.values(from:format:options:)`. The
/// writer does not do any I/O. Each call of `write` returns the bytes that need to be
/// appended to the output (a file, a network connection, ...). When all values were written,
/// `finish()` returns the closing bytes of the stream.
///
///     var writer = try JSONStreamWriter(format: .lines)
///     var output = Data()
///     output.append(try writer.write(["id": 1, "name": "Ada"]))
///     output.append(try writer.write(["id": 2, "name": "Alan"]))
///     output.append(try writer.finish())
///
/// What is written for each format:
///   - `lines`: each value on a line of its own (NDJSON, JSON Lines).
///   - `sequence`: each value preceded by a record separator (0x1E) and followed by a line
///     feed, as defined by RFC 7464.
///   - `concatenated`: the values one after the other, separated by `separator`.
///   - `arrayElements`: the values as elements of one JSON array. The array is opened by the
///     first value and closed by `finish()`.
///   - `serverSentEvents`: each value as the data of a server-sent event; see
///     `write(_:)` for events with names and identifiers.
///
/// Values written with any of the formats can be read again with
/// `JSON.values(from:format:options:)`.
///
public struct JSONStreamWriter {
  private let format: JSON.StreamFormat
  private let options: JSON.StreamWriteOptions
  private let encoder: JSONEncoder
  private let pretty: Bool
  private var count = 0
  private var isFinished = false
  
  /// Creates a writer for the given format. Throws an error if the format is
  /// `JSON.StreamFormat.automatic`, which cannot be used for writing, or if the options are not
  /// valid for the format.
  public init(format: JSON.StreamFormat,
              options: JSON.StreamWriteOptions = JSON.StreamWriteOptions()) throws {
    if format == .automatic {
      throw JSON.StreamWriteError.unsupportedFormat(format)
    }
    if format == .concatenated && !options.separator.utf8.allSatisfy(isJSONWhitespace) {
      throw JSON.StreamWriteError.invalidSeparator
    }
    var formatting = options.formatting
    if format == .lines {
      // One value per line requires that values do not contain line breaks
      formatting.remove(.prettyPrinted)
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = formatting
    encoder.keyEncodingStrategy = .useDefaultKeys
    encoder.dateEncodingStrategy = options.dateEncodingStrategy
    encoder.nonConformingFloatEncodingStrategy = options.floatEncodingStrategy
    if let userInfo = options.userInfo {
      encoder.userInfo = userInfo
    }
    self.format = format
    self.options = options
    self.encoder = encoder
    self.pretty = formatting.contains(.prettyPrinted)
  }
  
  /// The number of values that were written.
  public var valueCount: Int {
    return self.count
  }
  
  // MARK: - Writing values
  
  /// Writes a JSON value. Returns the bytes that need to be appended to the output.
  public mutating func write(_ value: JSON) throws -> Data {
    return try self.frame(try self.encode(value))
  }
  
  /// Writes a value of an `Encodable` type. This is more efficient than converting the value
  /// into a `JSON` value first. Returns the bytes that need to be appended to the output.
  public mutating func write<T: Encodable>(_ value: T) throws -> Data {
    return try self.frame(try self.encode(value))
  }
  
  /// Writes a server-sent event. This is only supported by format `serverSentEvents`.
  /// Returns the bytes that need to be appended to the output.
  public mutating func write(_ event: ServerSentEvent) throws -> Data {
    guard self.format == .serverSentEvents else {
      throw JSON.StreamWriteError.unsupportedOperation("writing events")
    }
    try self.checkNotFinished()
    self.count += 1
    return Data(event.encoded(lineEnding: self.options.lineEnding).utf8)
  }
  
  /// Writes a JSON value as a server-sent event with the given name, identifier, and
  /// reconnection time. This is only supported by format `serverSentEvents`.
  public mutating func write(_ value: JSON,
                             event: String?,
                             id: String? = nil,
                             retry: Int? = nil) throws -> Data {
    let data = String(decoding: try self.encode(value), as: UTF8.self)
    return try self.write(ServerSentEvent(event: event, data: data, id: id, retry: retry))
  }
  
  /// Writes a comment, which clients ignore. Servers use comments as keep-alive messages for
  /// connections that are otherwise idle. This is only supported by format `serverSentEvents`.
  public mutating func comment(_ text: String) throws -> Data {
    guard self.format == .serverSentEvents else {
      throw JSON.StreamWriteError.unsupportedOperation("writing comments")
    }
    try self.checkNotFinished()
    let eol = self.options.lineEnding.string
    let lines = ServerSentEvent.lines(of: text).map { ": \($0)\(eol)" }.joined()
    return Data((lines + eol).utf8)
  }
  
  /// Ends the stream and returns the bytes that need to be appended to the output. The writer
  /// does not accept any more values afterwards.
  public mutating func finish() throws -> Data {
    try self.checkNotFinished()
    self.isFinished = true
    switch self.format {
      case .arrayElements:
        if self.count == 0 {
          return Data((self.pretty ? "[]\n" : "[]").utf8)
        }
        return Data((self.pretty ? "\n]\n" : "]").utf8)
      case .serverSentEvents:
        guard let terminator = self.options.terminator else {
          return Data()
        }
        let event = ServerSentEvent(data: terminator)
        return Data(event.encoded(lineEnding: self.options.lineEnding).utf8)
      default:
        return Data()
    }
  }
  
  // MARK: - Framing
  
  private func checkNotFinished() throws {
    if self.isFinished {
      throw JSON.StreamWriteError.finished
    }
  }
  
  private func encode<T: Encodable>(_ value: T) throws -> Data {
    try self.checkNotFinished()
    do {
      return try self.encoder.encode(value)
    } catch let error {
      throw JSON.StreamWriteError.encoding(String(describing: error))
    }
  }
  
  /// Adds the framing of the format to the encoded value `body`.
  private mutating func frame(_ body: Data) throws -> Data {
    let first = self.count == 0
    self.count += 1
    var out = Data()
    switch self.format {
      case .automatic:
        break
      case .lines:
        out.append(body)
        out.append(contentsOf: self.options.lineEnding.string.utf8)
      case .sequence:
        out.append(0x1E)
        out.append(body)
        out.append(0x0A)
      case .concatenated:
        out.append(body)
        // Numbers and literals have to be separated from the next value by whitespace
        if let byte = body.first,
           byte != UInt8(ascii: "{") && byte != UInt8(ascii: "[") && byte != UInt8(ascii: "\""),
           self.options.separator.utf8.first.map({ !isJSONWhitespace($0) }) ?? true {
          out.append(0x20)
        }
        out.append(contentsOf: self.options.separator.utf8)
      case .arrayElements:
        if self.pretty {
          out.append(contentsOf: (first ? "[\n  " : ",\n  ").utf8)
          // Strings never contain line breaks, so all line breaks are indentation
          for byte in body {
            out.append(byte)
            if byte == 0x0A {
              out.append(contentsOf: [0x20, 0x20])
            }
          }
        } else {
          out.append(first ? UInt8(ascii: "[") : UInt8(ascii: ","))
          out.append(body)
        }
      case .serverSentEvents:
        let event = ServerSentEvent(data: String(decoding: body, as: UTF8.self))
        out.append(contentsOf: event.encoded(lineEnding: self.options.lineEnding).utf8)
    }
    return out
  }
}

extension ServerSentEvent {
  
  /// Creates an event whose data is the compact JSON encoding of `json`.
  public init(event: String? = nil, json: JSON, id: String? = nil, retry: Int? = nil) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes]
    let data: Data
    do {
      data = try encoder.encode(json)
    } catch let error {
      throw JSON.StreamWriteError.encoding(String(describing: error))
    }
    self.init(event: event, data: String(decoding: data, as: UTF8.self), id: id, retry: retry)
  }
  
  /// The bytes of this event in the `text/event-stream` format. Data that consists of several
  /// lines is written as several `data` fields. A client that reads the event reconstructs the
  /// data from them.
  public var encoded: Data {
    return Data(self.encoded(lineEnding: .lf).utf8)
  }
  
  internal func encoded(lineEnding: JSON.LineEnding) -> String {
    let eol = lineEnding.string
    var out = ""
    if let event = self.event {
      out += "event: \(ServerSentEvent.line(event))\(eol)"
    }
    if let id = self.id {
      out += "id: \(ServerSentEvent.line(id))\(eol)"
    }
    if let retry = self.retry {
      out += "retry: \(retry)\(eol)"
    }
    for line in ServerSentEvent.lines(of: self.data) {
      out += "data: \(line)\(eol)"
    }
    return out + eol
  }
  
  /// Splits text into lines, recognizing all line endings.
  internal static func lines(of text: String) -> [Substring] {
    return text.split(omittingEmptySubsequences: false,
                      whereSeparator: { $0 == "\n" || $0 == "\r" || $0 == "\r\n" })
  }
  
  /// Replaces line breaks in the value of a field, since fields consist of one line.
  private static func line(_ value: String) -> String {
    return value.split(omittingEmptySubsequences: false,
                       whereSeparator: { $0 == "\n" || $0 == "\r" || $0 == "\r\n" })
                .joined(separator: " ")
  }
}
