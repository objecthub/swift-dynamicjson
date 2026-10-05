//
//  EventSource.swift
//  WikiWatch
//
//  Created by Matthias Zenger on 05/10/2026.
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
import DynamicJSON

// WHAT THIS FILE SHOWS
// ====================
//
// How to read server-sent events (SSE) with DynamicJSON. SSE is the format in which many web
// APIs (including those of large language models) stream data: a long-running HTTP response of
// `text/event-stream` content, in which every event consists of lines such as
//
//     event: message
//     id: <identifier of the event>
//     data: {"some": "json"}
//
// and is terminated by an empty line.
//
// The entry point is `JSON.events(from:)`. It takes ANY asynchronous sequence of bytes
// (`AsyncSequence` of `UInt8`), for instance
//
//   - `URLSession.shared.bytes(for:)` (a live HTTP response),
//   - `url.resourceBytes` or `FileHandle.bytes` (files, pipes, standard input),
//   - your own sequence, such as `RecordingBytes` below,
//
// and returns an asynchronous sequence of `ServerSentEvent` values. Each event has the
// properties `event` (its name), `data` (the text of its data lines), `id`, and `retry`.
// Comments and unknown fields are skipped, and all line ending conventions are understood.
// Use `try event.json()` to parse its data.
//
// If you do not need the event names and ids, there is a shorter way. This turns a stream of
// bytes straight into a stream of `JSON` values, and finishes at a `[DONE]` event:
//
//     for try await json in JSON.values(from: bytes, format: .serverSentEvents) { ... }
//
// This tool needs the `id` of each event to resume after a dropped connection, so it uses
// `JSON.events(from:)`.

enum EventSourceError: LocalizedError {
  case unsupportedPlatform
  case unexpectedResponse(Int)
  case fileNotFound(String)
  
  var errorDescription: String? {
    switch self {
      case .unsupportedPlatform:
        return "live streaming is not supported on this platform; use --replay"
      case .unexpectedResponse(let status):
        return "server responded with HTTP status \(status)"
      case .fileNotFound(let path):
        return "cannot open '\(path)'"
    }
  }
}

///
/// Writes the bytes of a live session to a file, so that it can be replayed later.
///
final class Recorder: @unchecked Sendable {
  private let handle: FileHandle
  private var buffer = Data()
  
  init(path: String) throws {
    guard FileManager.default.createFile(atPath: path, contents: nil),
          let handle = FileHandle(forWritingAtPath: path) else {
      throw EventSourceError.fileNotFound(path)
    }
    self.handle = handle
  }
  
  func append(_ byte: UInt8) {
    self.buffer.append(byte)
    if self.buffer.count >= 16_384 {
      self.flush()
    }
  }
  
  func flush() {
    if !self.buffer.isEmpty {
      self.handle.write(self.buffer)
      self.buffer.removeAll(keepingCapacity: true)
    }
  }
}

///
/// An asynchronous sequence of bytes that passes on all bytes of another sequence, and
/// records them on the side. This shows that stream processing in DynamicJSON composes:
/// since `JSON.events(from:)` accepts any sequence of bytes, we can slip our own sequence
/// between the network and the SSE parser without the parser knowing about it.
///
struct RecordingBytes<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
  typealias Element = UInt8
  
  let base: Base
  let recorder: Recorder?
  
  func makeAsyncIterator() -> Iterator {
    return Iterator(base: self.base.makeAsyncIterator(), recorder: self.recorder)
  }
  
  struct Iterator: AsyncIteratorProtocol {
    var base: Base.AsyncIterator
    let recorder: Recorder?
    
    mutating func next() async throws -> UInt8? {
      let byte = try await self.base.next()
      if let byte {
        self.recorder?.append(byte)
      } else {
        self.recorder?.flush()
      }
      return byte
    }
  }
}

enum EventSource {
  static let userAgent = "WikiWatch/1.0 (https://github.com/objecthub/swift-dynamicjson)"
  
  // MARK: - Live stream
  
#if os(iOS) || os(watchOS) || os(tvOS) || os(macOS)
  /// Returns the server-sent events of a Wikimedia event stream. The connection is
  /// re-established with the `Last-Event-ID` header whenever it is closed (Wikimedia ends
  /// connections after about 15 minutes), using exponential backoff after errors.
  static func live(stream: String,
                   recorder: Recorder?,
                   verbose: Bool) -> AsyncThrowingStream<ServerSentEvent, Error> {
    return AsyncThrowingStream { continuation in
      let task = Task {
        var lastEventID: String? = nil
        var delay = 1.0
        while !Task.isCancelled {
          do {
            let url = URL(string: "https://stream.wikimedia.org/v2/stream/\(stream)")!
            var request = URLRequest(url: url)
            request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            if let lastEventID {
              request.setValue(lastEventID, forHTTPHeaderField: "Last-Event-ID")
            }
            // `bytes(for:)` returns as soon as the response headers have arrived. The body
            // is an `AsyncSequence` of bytes, which delivers data as it arrives.
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
              throw EventSourceError.unexpectedResponse(http.statusCode)
            }
            delay = 1.0
            // The loop ends when the server closes the connection; it throws if the connection
            // fails. Cancelling the task that runs this code ends it as well.
            for try await event in JSON.events(from: RecordingBytes(base: bytes,
                                                                    recorder: recorder)) {
              // The id of an event is sent back as `Last-Event-ID` when we reconnect, which
              // lets the server continue where we stopped. `event.id` is the id of the
              // most recent event that carried an `id` field.
              if let id = event.id {
                lastEventID = id
              }
              continuation.yield(event)
            }
            if verbose {
              fputs("connection closed; reconnecting\n", stderr)
            }
          } catch {
            if Task.isCancelled {
              break
            }
            if verbose {
              fputs("connection problem: \(error.localizedDescription); " +
                    "retrying in \(Int(delay)) s\n", stderr)
            }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            delay = min(delay * 2, 30)
          }
        }
        recorder?.flush()
        continuation.finish()
      }
      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }
#else
  static func live(stream: String,
                   recorder: Recorder?,
                   verbose: Bool) -> AsyncThrowingStream<ServerSentEvent, Error> {
    return AsyncThrowingStream { continuation in
      continuation.finish(throwing: EventSourceError.unsupportedPlatform)
    }
  }
#endif
  
  // MARK: - Replay
  
  /// Returns the time at which an event was created, taken from field `meta.dt`. This is
  /// used to replay captures with their original timing.
  static func time(of event: ServerSentEvent) -> Date? {
    // `try?` turns a parsing error into `nil`; the subscripts return `nil` for missing members.
    guard let json = try? event.json(),
          let text = json["meta"]?["dt"]?.stringValue else {
      return nil
    }
    return try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text)
  }
  
  /// Returns the bytes of a file (or of standard input, if `path` is `-`) as a stream.
  static func bytes(of path: String) throws -> AsyncThrowingStream<UInt8, Error> {
    let handle: FileHandle
    if path == "-" {
      handle = FileHandle.standardInput
    } else {
      guard let file = FileHandle(forReadingAtPath: path) else {
        throw EventSourceError.fileNotFound(path)
      }
      handle = file
    }
    return AsyncThrowingStream { continuation in
      let task = Task {
        do {
          while !Task.isCancelled, let chunk = try handle.read(upToCount: 65_536), !chunk.isEmpty {
            for byte in chunk {
              continuation.yield(byte)
            }
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }
  
  /// Returns the events of a recorded capture. Unless `speed` is 0, events are delivered
  /// with the timing they originally had, divided by `speed`.
  static func replay(path: String,
                     speed: Double) throws -> AsyncThrowingStream<ServerSentEvent, Error> {
    let bytes = try self.bytes(of: path)
    return AsyncThrowingStream { continuation in
      let task = Task {
        do {
          var previous: Date? = nil
          // Reading a recording works just like reading the live connection: the same
          // function parses the bytes, no matter where they come from.
          for try await event in JSON.events(from: bytes) {
            if speed > 0, let time = self.time(of: event) {
              if let previous, time > previous {
                let seconds = time.timeIntervalSince(previous) / speed
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
              }
              previous = max(previous ?? time, time)
            }
            continuation.yield(event)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }
}
