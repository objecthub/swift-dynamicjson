//
//  JSONStreamWriterTests.swift
//  DynamicJSONTests
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

import XCTest
import DynamicJSON

final class JSONStreamWriterTests: XCTestCase {
  
  private let formats: [JSON.StreamFormat] = [.lines, .sequence, .concatenated, .arrayElements,
                                              .serverSentEvents]
  
  private func text(_ data: Data) -> String {
    return String(decoding: data, as: UTF8.self)
  }
  
  private func write(_ values: [JSON],
                     _ format: JSON.StreamFormat,
                     _ options: JSON.StreamWriteOptions = .init()) throws -> String {
    return self.text(try JSON.stream(values, format: format, options: options))
  }
  
  private func chunks<S: AsyncSequence>(_ stream: S) async throws -> [Data] where S.Element == Data {
    var res: [Data] = []
    for try await chunk in stream {
      res.append(chunk)
    }
    return res
  }
  
  private func asyncValues(_ values: [JSON]) -> AsyncStream<JSON> {
    return AsyncStream<JSON> { continuation in
      for value in values {
        continuation.yield(value)
      }
      continuation.finish()
    }
  }
  
  // MARK: - Formats
  
  func testLines() throws {
    let values: [JSON] = [1, "a", [1, 2], ["a": 1], nil, true]
    XCTAssertEqual(try self.write(values, .lines), "1\n\"a\"\n[1,2]\n{\"a\":1}\nnull\ntrue\n")
    XCTAssertEqual(try self.write(values, .lines, .init(lineEnding: .crlf)),
                   "1\r\n\"a\"\r\n[1,2]\r\n{\"a\":1}\r\nnull\r\ntrue\r\n")
    XCTAssertEqual(try self.write([], .lines), "")
    // Pretty printing is not possible: one line per value
    XCTAssertEqual(try self.write([["a": [1, 2]]], .lines, .init(formatting: [.prettyPrinted])),
                   "{\"a\":[1,2]}\n")
  }
  
  func testSequence() throws {
    XCTAssertEqual(try self.write([1, ["a": 1], "x"], .sequence),
                   "\u{1E}1\n\u{1E}{\"a\":1}\n\u{1E}\"x\"\n")
    XCTAssertEqual(try self.write([], .sequence), "")
    // Line feeds are used even if CRLF is requested for lines
    XCTAssertEqual(try self.write([1], .sequence, .init(lineEnding: .crlf)), "\u{1E}1\n")
  }
  
  func testConcatenated() throws {
    XCTAssertEqual(try self.write([1, 2, ["a": 1]], .concatenated), "1\n2\n{\"a\":1}\n")
    XCTAssertEqual(try self.write([["a": 1], ["b": 2], [3], "x"], .concatenated, .init(separator: "")),
                   "{\"a\":1}{\"b\":2}[3]\"x\"")
    // Numbers and literals are separated from the following value by whitespace
    XCTAssertEqual(try self.write([1, 2, true, nil, ["a": 1]], .concatenated, .init(separator: "")),
                   "1 2 true null {\"a\":1}")
    XCTAssertEqual(try self.write([1, 2], .concatenated, .init(separator: "\n\n")), "1\n\n2\n\n")
    XCTAssertThrowsError(try JSONStreamWriter(format: .concatenated,
                                              options: .init(separator: ","))) { error in
      XCTAssertEqual(error as? JSON.StreamWriteError, .invalidSeparator)
    }
  }
  
  func testArrayElements() throws {
    XCTAssertEqual(try self.write([1, ["a": 1], "x"], .arrayElements), "[1,{\"a\":1},\"x\"]")
    XCTAssertEqual(try self.write([], .arrayElements), "[]")
    XCTAssertEqual(try self.write([[:]], .arrayElements), "[{}]")
    let pretty = JSON.StreamWriteOptions(formatting: [.prettyPrinted, .sortedKeys])
    let text = try self.write([["a": [1, 2], "b": nil], 3], .arrayElements, pretty)
    XCTAssertTrue(text.hasPrefix("[\n  {\n    \"a\""))
    XCTAssertTrue(text.hasSuffix("\n  },\n  3\n]\n"))
    XCTAssertEqual(try JSON(string: text), [["a": [1, 2], "b": nil], 3])
    XCTAssertEqual(try self.write([], .arrayElements, pretty), "[]\n")
  }
  
  func testServerSentEvents() throws {
    XCTAssertEqual(try self.write([["a": 1], 2], .serverSentEvents),
                   "data: {\"a\":1}\n\ndata: 2\n\n")
    XCTAssertEqual(try self.write([1], .serverSentEvents, .init(lineEnding: .crlf)),
                   "data: 1\r\n\r\n")
    XCTAssertEqual(try self.write([1, 2], .serverSentEvents, .init(terminator: "[DONE]")),
                   "data: 1\n\ndata: 2\n\ndata: [DONE]\n\n")
    // Pretty-printed values become several data fields
    let pretty = try self.write([["a": [1]]], .serverSentEvents,
                                .init(formatting: [.prettyPrinted, .sortedKeys]))
    XCTAssertTrue(pretty.hasPrefix("data: {\ndata:   \"a\""))
    XCTAssertEqual(try JSON.values(from: pretty, format: .serverSentEvents), [["a": [1]]])
  }
  
  func testServerSentEventEncoding() throws {
    let event = ServerSentEvent(event: "update", data: "line 1\nline 2\r\nline 3", id: "7", retry: 1000)
    XCTAssertEqual(self.text(event.encoded),
                   "event: update\nid: 7\nretry: 1000\ndata: line 1\ndata: line 2\ndata: line 3\n\n")
    XCTAssertEqual(self.text(ServerSentEvent(data: "").encoded), "data: \n\n")
    XCTAssertEqual(self.text(ServerSentEvent(event: "a\nb", data: "x", id: "i\rd").encoded),
                   "event: a b\nid: i d\ndata: x\n\n")
    XCTAssertEqual(self.text(try ServerSentEvent(event: "e", json: ["k": "v"]).encoded),
                   "event: e\ndata: {\"k\":\"v\"}\n\n")
    var writer = try JSONStreamWriter(format: .serverSentEvents)
    var output = Data()
    output.append(try writer.comment("keep-alive"))
    output.append(try writer.write(["n": 1], event: "tick", id: "1"))
    output.append(try writer.write(["n": 2], event: "tick", id: "2", retry: 50))
    output.append(try writer.write(ServerSentEvent(data: "plain")))
    XCTAssertEqual(self.text(output),
                   ": keep-alive\n\nevent: tick\nid: 1\ndata: {\"n\":1}\n\n" +
                   "event: tick\nid: 2\nretry: 50\ndata: {\"n\":2}\n\ndata: plain\n\n")
    // The events can be read again
    XCTAssertEqual(JSON.events(from: output), [
      ServerSentEvent(event: "tick", data: "{\"n\":1}", id: "1"),
      ServerSentEvent(event: "tick", data: "{\"n\":2}", id: "2", retry: 50),
      ServerSentEvent(data: "plain", id: "2")
    ])
  }
  
  // MARK: - Round trips
  
  func testNastyStringsDoNotConfuseFraming() throws {
    let strings = ["line 1\nline 2", "a\r\nb", "x\u{2028}y\u{2029}z", "\u{1E}record\u{1E}", "data: x\n\ndata: y",
                   "] [ } {", "\"quoted\" \\ back\\slash /", "tab\there", "\u{0}\u{1}\u{1F}", "日本語 😀"]
    let values = strings.map { JSON.string($0) } + [["key\nwith\nbreaks": .array(strings.map { JSON.string($0) })]]
    for format in self.formats {
      let data = try JSON.stream(values, format: format)
      XCTAssertEqual(try JSON.values(from: data, format: format), values, "\(format)")
    }
    // A value never contains a line break, so there are exactly as many lines as values
    let lines = try JSON.stream(values, format: .lines)
    XCTAssertEqual(lines.filter { $0 == 0x0A }.count, values.count)
    let sequence = try JSON.stream(values, format: .sequence)
    XCTAssertEqual(sequence.filter { $0 == 0x1E }.count, values.count)
  }
  
  func testRandomValuesRoundTrip() throws {
    var generator = ValueGenerator(seed: 42)
    let values = (0..<200).map { _ in generator.value(depth: 4) }
    let variants: [JSON.StreamWriteOptions] = [
      .init(),
      .init(formatting: [.sortedKeys]),
      .init(formatting: [.prettyPrinted, .sortedKeys]),
      .init(lineEnding: .crlf, separator: "\r\n\r\n")
    ]
    for format in self.formats {
      for options in variants {
        let data = try JSON.stream(values, format: format, options: options)
        XCTAssertEqual(try JSON.values(from: data, format: format), values, "\(format)")
      }
    }
    // Scalars only, which need whitespace in between
    let scalars: [JSON] = [1, 2, -3, 4.5, true, false, nil, "a", "b", 7]
    for format in self.formats {
      let data = try JSON.stream(scalars, format: format, options: .init(separator: ""))
      XCTAssertEqual(try JSON.values(from: data, format: format), scalars, "\(format)")
    }
  }
  
  func testEmptyStreams() throws {
    for format in self.formats {
      let data = try JSON.stream([], format: format)
      XCTAssertEqual(try JSON.values(from: data, format: format), [], "\(format)")
    }
  }
  
  func testTypedValues() throws {
    struct Person: Codable, Equatable {
      let name: String
      let age: Int
      let tags: [String]
    }
    let people = [Person(name: "Ada", age: 36, tags: ["math"]),
                  Person(name: "Alan", age: 41, tags: [])]
    for format in self.formats {
      let data = try JSON.stream(encoding: people, format: format,
                                 options: .init(formatting: [.sortedKeys]))
      let values = try JSON.values(from: data, format: format)
      XCTAssertEqual(try values.map { try $0.coerce() as Person }, people, "\(format)")
    }
    var writer = try JSONStreamWriter(format: .lines, options: .init(formatting: [.sortedKeys]))
    XCTAssertEqual(self.text(try writer.write(people[0])),
                   "{\"age\":36,\"name\":\"Ada\",\"tags\":[\"math\"]}\n")
    XCTAssertEqual(writer.valueCount, 1)
  }
  
  // MARK: - Errors
  
  func testErrors() throws {
    XCTAssertThrowsError(try JSONStreamWriter(format: .automatic)) { error in
      XCTAssertEqual(error as? JSON.StreamWriteError, .unsupportedFormat(.automatic))
    }
    XCTAssertThrowsError(try JSON.stream([1], format: .automatic))
    // Values that cannot be encoded
    XCTAssertThrowsError(try self.write([.float(.nan)], .lines)) { error in
      guard case .encoding(_)? = error as? JSON.StreamWriteError else {
        return XCTFail("unexpected error \(error)")
      }
    }
    XCTAssertThrowsError(try self.write([.float(.infinity)], .arrayElements))
    XCTAssertEqual(try self.write([.float(.nan), .float(-.infinity)], .lines,
                                  .init(floatEncodingStrategy: .convertToString(
                                    positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan"))),
                   "\"nan\"\n\"-inf\"\n")
    // Writers can only be used until they are finished
    var writer = try JSONStreamWriter(format: .lines)
    _ = try writer.write(1)
    _ = try writer.finish()
    XCTAssertThrowsError(try writer.write(2)) { error in
      XCTAssertEqual(error as? JSON.StreamWriteError, .finished)
    }
    XCTAssertThrowsError(try writer.finish())
    // Events and comments are only for server-sent events
    var lines = try JSONStreamWriter(format: .lines)
    XCTAssertThrowsError(try lines.write(ServerSentEvent(data: "x")))
    XCTAssertThrowsError(try lines.comment("x"))
    XCTAssertThrowsError(try lines.write(1, event: "e"))
  }
  
  // MARK: - Asynchronous streams
  
  func testByteStreamChunks() async throws {
    let values: [JSON] = [1, ["a": 2], "x"]
    let lines = try await self.chunks(JSON.stream(self.asyncValues(values), format: .lines))
    XCTAssertEqual(lines.map { self.text($0) }, ["1\n", "{\"a\":2}\n", "\"x\"\n"])
    // The array format has a chunk with its closing bracket
    let array = try await self.chunks(JSON.stream(self.asyncValues(values), format: .arrayElements))
    XCTAssertEqual(array.map { self.text($0) }, ["[1", ",{\"a\":2}", ",\"x\"", "]"])
    let empty = try await self.chunks(JSON.stream(self.asyncValues([]), format: .arrayElements))
    XCTAssertEqual(empty.map { self.text($0) }, ["[]"])
    let none = try await self.chunks(JSON.stream(self.asyncValues([]), format: .lines))
    XCTAssertTrue(none.isEmpty)
    // All formats read back
    for format in self.formats {
      var data = Data()
      for chunk in try await self.chunks(JSON.stream(self.asyncValues(values), format: format)) {
        data.append(chunk)
      }
      XCTAssertEqual(try JSON.values(from: data, format: format), values, "\(format)")
      XCTAssertEqual(data, try JSON.stream(values, format: format), "\(format)")
    }
  }
  
  func testByteStreamErrors() async throws {
    do {
      _ = try await self.chunks(JSON.stream(self.asyncValues([1, .float(.nan), 3]), format: .lines))
      XCTFail("expected error")
    } catch {
      XCTAssertTrue(error is JSON.StreamWriteError)
    }
    do {
      _ = try await self.chunks(JSON.stream(self.asyncValues([1]), format: .automatic))
      XCTFail("expected error")
    } catch {
      XCTAssertEqual(error as? JSON.StreamWriteError, .unsupportedFormat(.automatic))
    }
    // Errors of the underlying sequence are passed on
    struct SourceError: Error {}
    let failing = AsyncThrowingStream<JSON, Error> { continuation in
      continuation.yield(1)
      continuation.finish(throwing: SourceError())
    }
    var received: [Data] = []
    do {
      for try await chunk in JSON.stream(failing, format: .lines) {
        received.append(chunk)
      }
      XCTFail("expected error")
    } catch {
      XCTAssertTrue(error is SourceError)
    }
    XCTAssertEqual(received.map { self.text($0) }, ["1\n"])
  }
  
  func testTypedAndEventStreams() async throws {
    let numbers = AsyncStream<Int> { continuation in
      for i in 1...3 {
        continuation.yield(i)
      }
      continuation.finish()
    }
    let numberChunks = try await self.chunks(JSON.stream(encoding: numbers, format: .sequence))
    XCTAssertEqual(numberChunks.map { self.text($0) }, ["\u{1E}1\n", "\u{1E}2\n", "\u{1E}3\n"])
    let events = AsyncStream<ServerSentEvent> { continuation in
      continuation.yield(ServerSentEvent(event: "a", data: "1"))
      continuation.yield(ServerSentEvent(data: "2"))
      continuation.finish()
    }
    let eventChunks = try await self.chunks(JSON.stream(events: events,
                                                        options: .init(terminator: "[DONE]")))
    XCTAssertEqual(eventChunks.map { self.text($0) },
                   ["event: a\ndata: 1\n\n", "data: 2\n\n", "data: [DONE]\n\n"])
  }
  
  func testRelayOfPartialValues() async throws {
    // Streaming partial JSON values as patches over server-sent events and applying them again
    let fragments = AsyncStream<String> { continuation in
      for piece in [#"{"a": [1, "#, #"2], "b": "he"#, #"llo"}"#] {
        continuation.yield(piece)
      }
      continuation.finish()
    }
    let patches = AsyncStream<ServerSentEvent> { continuation in
      Task {
        do {
          var previous: PartialJSON? = nil
          for try await partial in JSON.partialValues(from: fragments) {
            let patch = partial.patch(from: previous)
            continuation.yield(try ServerSentEvent(event: "patch",
                                                   json: try JSON(encodable: patch)))
            previous = partial
          }
        } catch {
          XCTFail("unexpected error \(error)")
        }
        continuation.finish()
      }
    }
    var bytes = Data()
    for try await chunk in JSON.stream(events: patches) {
      bytes.append(chunk)
    }
    var value = JSON.null
    for event in JSON.events(from: bytes) {
      XCTAssertEqual(event.event, "patch")
      try value.apply(patch: JSONPatch(try event.json()))
    }
    XCTAssertEqual(value, ["a": [1, 2], "b": "hello"])
  }
  
  // MARK: - Files
  
  func testFiles() async throws {
    let values: [JSON] = [["id": 1, "tags": ["a", "b"]], ["id": 2, "tags": []], "text"]
    let directory = FileManager.default.temporaryDirectory
    for format in self.formats {
      let syncURL = directory.appendingPathComponent("\(UUID()).stream")
      let asyncURL = directory.appendingPathComponent("\(UUID()).stream")
      defer {
        try? FileManager.default.removeItem(at: syncURL)
        try? FileManager.default.removeItem(at: asyncURL)
      }
      try JSON.write(values, to: syncURL, format: format)
      try await JSON.write(self.asyncValues(values), to: asyncURL, format: format)
      let syncData = try Data(contentsOf: syncURL)
      XCTAssertEqual(syncData, try Data(contentsOf: asyncURL), "\(format)")
      XCTAssertEqual(try JSON.values(from: syncData, format: format), values, "\(format)")
    }
    // An existing file is replaced
    let url = directory.appendingPathComponent("\(UUID()).ndjson")
    defer {
      try? FileManager.default.removeItem(at: url)
    }
    try JSON.write([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], to: url, format: .lines)
    try JSON.write([1], to: url, format: .lines)
    XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "1\n")
  }
  
  // MARK: - Real-world data
  
  private func dataURL(_ name: String) -> URL {
    let bundle = Bundle(for: type(of: self))
    if let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "JSONStream") {
      return url
    }
    return URL(fileURLWithPath: "Tests/DynamicJSONTests/ComplianceTests/JSONStream/\(name)")
  }
  
  func testRoundTripOfRealData() throws {
    let tweets = try XCTUnwrap(JSON(data: try Data(contentsOf: self.dataURL("twitter.json")))
                                 .statuses?.arrayValue)
    let phones = try String(contentsOf: self.dataURL("amazon_cellphones.ndjson"), encoding: .utf8)
      .split(separator: "\n").map { try JSON(string: String($0)) }
    let catalog = try JSON(data: try Data(contentsOf: self.dataURL("citm_catalog.json")))
    for (name, values) in [("tweets", tweets), ("phones", phones), ("catalog", [catalog])] {
      for format in self.formats {
        for options in [JSON.StreamWriteOptions(), .init(formatting: [.prettyPrinted, .sortedKeys])] {
          let data = try JSON.stream(values, format: format, options: options)
          XCTAssertEqual(try JSON.values(from: data, format: format), values, "\(name) \(format)")
        }
      }
    }
  }
}

/// A generator of pseudo-random JSON values (deterministic for a given seed).
private struct ValueGenerator {
  private var state: UInt64
  
  init(seed: UInt64) {
    self.state = seed &* 6364136223846793005 &+ 1442695040888963407
  }
  
  private mutating func next(_ bound: Int) -> Int {
    self.state = self.state &* 6364136223846793005 &+ 1442695040888963407
    return Int((self.state >> 33) % UInt64(bound))
  }
  
  private static let strings = ["", "a", "hello world", "line\nbreak", "tab\t", "quote\"", "back\\slash",
                                "slash/", "é", "日本語", "😀", "\u{1E}", "\u{2028}", "data: x", "]}",
                                "\u{1}\u{1F}"]
  
  mutating func value(depth: Int) -> JSON {
    switch self.next(depth > 0 ? 8 : 6) {
      case 0:
        return nil
      case 1:
        return .boolean(self.next(2) == 0)
      case 2:
        return .integer(Int64(self.next(2_000_000)) - 1_000_000)
      case 3:
        // Only fractions, since floats without a fractional part are read as integers
        return .float(Double(self.next(1_000_000)) + 0.5)
      case 4, 5:
        return .string(ValueGenerator.strings[self.next(ValueGenerator.strings.count)])
      case 6:
        return .array((0..<self.next(5)).map { _ in self.value(depth: depth - 1) })
      default:
        var object: [String : JSON] = [:]
        for _ in 0..<self.next(5) {
          object[ValueGenerator.strings[self.next(ValueGenerator.strings.count)]] =
              self.value(depth: depth - 1)
        }
        return .object(object)
    }
  }
}
