//
//  ServerSentEvents.swift
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
/// An event of a server-sent event stream (`text/event-stream`), as specified by the
/// WHATWG HTML standard. Servers use this format for pushing events to clients; it is
/// the transport used by most streaming APIs for large language models.
///
public struct ServerSentEvent: Hashable, Sendable {
  
  /// The name of the event, taken from the `event` field. It is `nil` for unnamed events.
  public var event: String?
  
  /// The data of the event. Multiple `data` fields of an event are joined with line feeds.
  public var data: String
  
  /// The last event identifier, as set by the `id` field of this or an earlier event.
  public var id: String?
  
  /// The reconnection time in milliseconds, if set by the `retry` field of this event.
  public var retry: Int?
  
  /// Creates a server-sent event.
  public init(event: String? = nil, data: String, id: String? = nil, retry: Int? = nil) {
    self.event = event
    self.data = data
    self.id = id
    self.retry = retry
  }
  
  /// Decodes the data of this event as a JSON value.
  public func json() throws -> JSON {
    return try JSON(string: self.data)
  }
}

///
/// A `SSEParser` splits a stream of bytes into server-sent events, following the parsing
/// rules of the WHATWG HTML standard: lines end with `\n`, `\r\n` or `\r`; lines starting
/// with `:` are comments; empty lines dispatch the event collected so far; an event
/// that is incomplete at the end of the stream is dropped.
///
internal struct SSEParser {
  private static let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
  
  private var line: [UInt8] = []
  private var lineStart = 0
  private var sawCarriageReturn = false
  private var bomMatched = 0
  private var atStart = true
  private var offset = 0
  
  private var data: [UInt8] = []
  private var hasData = false
  private var eventName: String? = nil
  private var eventStart: Int? = nil
  private var retry: Int? = nil
  private var lastEventId: String? = nil
  
  /// The number of bytes of the event that is currently being collected.
  var pendingSize: Int {
    return self.data.count + self.line.count
  }
  
  /// Processes the next byte. If the byte completes an event, the event and the offset of
  /// its first field are returned.
  mutating func push(_ byte: UInt8) -> (event: ServerSentEvent, offset: Int)? {
    let pos = self.offset
    self.offset += 1
    if self.atStart {
      if self.bomMatched < 3 && byte == SSEParser.bom[self.bomMatched] {
        self.bomMatched += 1
        if self.bomMatched == 3 {
          self.atStart = false
        }
        return nil
      }
      self.atStart = false
      // A partial byte order mark is not a byte order mark.
      for b in SSEParser.bom[0..<self.bomMatched] {
        _ = self.consume(b, at: pos)
      }
      self.bomMatched = 0
    }
    return self.consume(byte, at: pos)
  }
  
  private mutating func consume(_ byte: UInt8,
                                at pos: Int) -> (event: ServerSentEvent, offset: Int)? {
    if byte == 0x0A && self.sawCarriageReturn {
      self.sawCarriageReturn = false
      return nil
    }
    self.sawCarriageReturn = byte == 0x0D
    if byte == 0x0A || byte == 0x0D {
      return self.endLine()
    }
    if self.line.isEmpty {
      self.lineStart = pos
    }
    self.line.append(byte)
    return nil
  }
  
  private mutating func endLine() -> (event: ServerSentEvent, offset: Int)? {
    defer {
      self.line.removeAll(keepingCapacity: true)
    }
    if self.line.isEmpty {
      return self.dispatch()
    }
    if self.line[0] == UInt8(ascii: ":") {
      return nil
    }
    var name = self.line[...]
    var value: ArraySlice<UInt8> = []
    if let colon = self.line.firstIndex(of: UInt8(ascii: ":")) {
      name = self.line[..<colon]
      value = self.line[(colon + 1)...]
      if value.first == UInt8(ascii: " ") {
        value = value.dropFirst()
      }
    }
    if self.eventStart == nil {
      self.eventStart = self.lineStart
    }
    switch String(decoding: name, as: UTF8.self) {
      case "event":
        self.eventName = String(decoding: value, as: UTF8.self)
      case "data":
        self.data.append(contentsOf: value)
        self.data.append(0x0A)
        self.hasData = true
      case "id":
        if !value.contains(0) {
          self.lastEventId = String(decoding: value, as: UTF8.self)
        }
      case "retry":
        if !value.isEmpty && value.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }) {
          self.retry = Int(String(decoding: value, as: UTF8.self))
        }
      default:
        break
    }
    return nil
  }
  
  private mutating func dispatch() -> (event: ServerSentEvent, offset: Int)? {
    defer {
      self.data.removeAll(keepingCapacity: true)
      self.hasData = false
      self.eventName = nil
      self.eventStart = nil
      self.retry = nil
    }
    guard self.hasData else {
      return nil
    }
    // Remove the line feed added after the last data field
    let event = ServerSentEvent(event: self.eventName,
                                data: String(decoding: self.data.dropLast(), as: UTF8.self),
                                id: self.lastEventId,
                                retry: self.retry)
    return (event, self.eventStart ?? self.lineStart)
  }
}

///
/// An asynchronous sequence of the server-sent events found in an asynchronous sequence of
/// bytes. Use `JSON.events(from:)` to create a `ServerSentEventStream`.
///
public struct ServerSentEventStream<Base: AsyncSequence>: AsyncSequence
                                                          where Base.Element == UInt8 {
  public typealias Element = ServerSentEvent
  
  private let base: Base
  
  internal init(base: Base) {
    self.base = base
  }
  
  public func makeAsyncIterator() -> AsyncIterator {
    return AsyncIterator(base: self.base.makeAsyncIterator())
  }
  
  public struct AsyncIterator: AsyncIteratorProtocol {
    private var base: Base.AsyncIterator
    private var parser = SSEParser()
    
    internal init(base: Base.AsyncIterator) {
      self.base = base
    }
    
    public mutating func next() async throws -> ServerSentEvent? {
      while let byte = try await self.base.next() {
        if let (event, _) = self.parser.push(byte) {
          return event
        }
      }
      return nil
    }
  }
}

extension ServerSentEventStream: Sendable where Base: Sendable {}

extension JSON {
  
  /// Returns an asynchronous sequence of the server-sent events (`text/event-stream`)
  /// found in `bytes`. Use this function instead of
  /// `JSON.values(from:format:options:)` with format `JSON.StreamFormat.serverSentEvents`
  /// if the event names or identifiers matter, or if the data of events is not JSON.
  ///
  ///     for try await event in JSON.events(from: response.bytes) {
  ///       switch event.event {
  ///         case "content_block_delta": print(try event.json())
  ///         default: break
  ///       }
  ///     }
  public static func events<S: AsyncSequence>(
      from bytes: S) -> ServerSentEventStream<S> where S.Element == UInt8 {
    return ServerSentEventStream(base: bytes)
  }
  
  /// Returns all server-sent events found in `bytes` (e.g. a `Data` object).
  public static func events<S: Sequence>(from bytes: S) -> [ServerSentEvent]
                                                    where S.Element == UInt8 {
    var parser = SSEParser()
    var res: [ServerSentEvent] = []
    for byte in bytes {
      if let (event, _) = parser.push(byte) {
        res.append(event)
      }
    }
    return res
  }
}
