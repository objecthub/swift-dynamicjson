//
//  JSONServerSentEventTests.swift
//  DynamicJSONTests
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

import XCTest
import DynamicJSON

final class JSONServerSentEventTests: XCTestCase {
  
  private func events(_ text: String) -> [ServerSentEvent] {
    return JSON.events(from: Array(text.utf8))
  }
  
  private func stream(_ text: String) -> AsyncStream<UInt8> {
    return AsyncStream<UInt8> { continuation in
      for byte in text.utf8 {
        continuation.yield(byte)
      }
      continuation.finish()
    }
  }
  
  // MARK: - Event parsing
  
  func testBasicEvents() {
    let events = self.events("data: one\n\nevent: greeting\ndata: two\nid: 7\nretry: 500\n\n")
    XCTAssertEqual(events, [
      ServerSentEvent(data: "one"),
      ServerSentEvent(event: "greeting", data: "two", id: "7", retry: 500)
    ])
  }
  
  func testMultilineData() {
    XCTAssertEqual(self.events("data: a\ndata: b\ndata\n\n"),
                   [ServerSentEvent(data: "a\nb\n")])
  }
  
  func testCommentsAndUnknownFields() {
    let events = self.events(": keep-alive\n\nfoo: bar\n: comment\ndata:x\n\n")
    XCTAssertEqual(events, [ServerSentEvent(data: "x")])
  }
  
  func testLineTerminators() {
    XCTAssertEqual(self.events("data: a\r\n\r\ndata: b\r\rdata: c\n\n").map { $0.data },
                   ["a", "b", "c"])
  }
  
  func testByteOrderMark() {
    XCTAssertEqual(self.events("\u{FEFF}data: a\n\n").map { $0.data }, ["a"])
  }
  
  func testIncompleteEventIsDropped() {
    XCTAssertEqual(self.events("data: a\n\ndata: b\n").map { $0.data }, ["a"])
  }
  
  func testLastEventIdPersists() {
    let events = self.events("id: 1\ndata: a\n\ndata: b\n\nid: 2\ndata: c\n\n")
    XCTAssertEqual(events.map { $0.id }, ["1", "1", "2"])
  }
  
  func testInvalidRetryAndEmptyData() {
    let events = self.events("retry: soon\nevent: x\n\ndata: y\nretry: 10x\n\n")
    XCTAssertEqual(events, [ServerSentEvent(data: "y")])
  }
  
  // MARK: - JSON values
  
  func testJSONValues() throws {
    let input = "data: {\"a\": 1}\n\n: ping\n\ndata: [1,\ndata: 2]\n\ndata: [DONE]\n\ndata: 5\n\n"
    let values = try JSON.values(from: input, format: .serverSentEvents)
    XCTAssertEqual(values, [["a": 1], [1, 2]])
  }
  
  func testTerminatorOption() throws {
    let input = "data: 1\n\ndata: END\n\ndata: 2\n\n"
    XCTAssertEqual(try JSON.values(from: input, format: .serverSentEvents,
                                   options: .init(terminator: "END")), [1])
    XCTAssertEqual(try JSON.values(from: "data: 1\n\ndata: 2\n\n",
                                   format: .serverSentEvents,
                                   options: .init(terminator: nil)), [1, 2])
  }
  
  func testInvalidData() throws {
    let input = "data: 1\n\ndata: oops\n\ndata: 3\n\n"
    XCTAssertThrowsError(try JSON.values(from: input, format: .serverSentEvents))
    XCTAssertEqual(try JSON.values(from: input,
                                   format: .serverSentEvents,
                                   options: .init(errors: .skipInvalid)), [1, 3])
  }
  
  func testAutomaticDetection() throws {
    XCTAssertEqual(try JSON.values(from: "data: 1\n\ndata: 2\n\n"), [1, 2])
    XCTAssertEqual(try JSON.values(from: ": hello\n\nevent: x\ndata: {}\n\n"), [[:]])
    XCTAssertEqual(try JSON.values(from: "\n\ndata: true\n\n"), [true])
  }
  
  func testMaxValueSize() throws {
    let input = "data: [1,2,3,4,5,6,7,8,9]\n\n"
    XCTAssertThrowsError(try JSON.values(from: input, format: .serverSentEvents,
                                         options: .init(maxValueSize: 10)))
    XCTAssertEqual(try JSON.values(from: input, format: .serverSentEvents,
                                   options: .init(maxValueSize: 100)).count, 1)
  }
  
  // MARK: - Asynchronous streams
  
  func testAsyncEvents() async throws {
    var res: [ServerSentEvent] = []
    for try await event in JSON.events(from: self.stream("event: a\ndata: 1\n\ndata: 2\n\n")) {
      res.append(event)
    }
    XCTAssertEqual(res, [ServerSentEvent(event: "a", data: "1"), ServerSentEvent(data: "2")])
  }
  
  // MARK: - OpenAI- and Anthropic-style transcripts
  
  func testChatCompletionTranscript() async throws {
    let transcript = """
      data: {"id":"1","choices":[{"index":0,"delta":{"role":"assistant","content":""}}]}
      
      data: {"id":"1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"ci"}}]}}]}
      
      data: {"id":"1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"ty\\": \\"Pa"}}]}}]}
      
      data: {"id":"1","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"ris\\", \\"days\\": 3}"}}]}}]}
      
      data: {"id":"1","choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}
      
      data: [DONE]
      
      
      """
    let events = JSON.values(from: self.stream(transcript), format: .serverSentEvents)
    let pointer = try JSONPointer("/choices/0/delta/tool_calls/0/function/arguments")
    var snapshots: [PartialJSON] = []
    for try await partial in JSON.partialValues(from: JSON.fragments(from: events, at: pointer)) {
      snapshots.append(partial)
    }
    XCTAssertEqual(snapshots.map { $0.value },
                   [[:], ["city": "Pa"], ["city": "Paris", "days": 3]])
    XCTAssertEqual(snapshots.map { $0.isComplete }, [false, false, true])
    XCTAssertEqual(snapshots.last, PartialJSON(value: ["city": "Paris", "days": 3], isComplete: true))
  }
  
  func testMessagesTranscript() async throws {
    let transcript = """
      event: message_start
      data: {"type":"message_start","message":{"id":"msg_1"}}
      
      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\\"items\\": [1, "}}
      
      event: ping
      data: {"type": "ping"}
      
      event: content_block_delta
      data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"2, 3]}"}}
      
      event: message_stop
      data: {"type":"message_stop"}
      
      
      """
    let events = JSON.values(from: self.stream(transcript), format: .serverSentEvents)
    let pointer = try JSONPointer("/delta/partial_json")
    var last: PartialJSON? = nil
    for try await partial in JSON.partialValues(from: JSON.fragments(from: events, at: pointer)) {
      last = partial
    }
    XCTAssertEqual(last, PartialJSON(value: ["items": [1, 2, 3]], isComplete: true))
    // Event names are available via `JSON.events(from:)`
    var names: [String] = []
    for try await event in JSON.events(from: self.stream(transcript)) {
      names.append(event.event ?? "")
    }
    XCTAssertEqual(names, ["message_start", "content_block_delta", "ping",
                           "content_block_delta", "message_stop"])
  }
}
