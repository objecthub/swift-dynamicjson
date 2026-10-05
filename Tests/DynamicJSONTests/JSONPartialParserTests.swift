//
//  JSONPartialParserTests.swift
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

final class JSONPartialParserTests: XCTestCase {
  
  /// Is `partial` a prefix of `complete`, i.e. can `partial` be extended to `complete` by
  /// adding members and elements, and by appending text to strings?
  private func isPrefix(_ partial: JSON, of complete: JSON) -> Bool {
    switch (partial, complete) {
      case (.string(let p), .string(let c)):
        // Compare code units, since a prefix may end in the middle of a grapheme cluster
        return c.utf8.starts(with: p.utf8)
      case (.array(let p), .array(let c)):
        return p.count <= c.count && zip(p, c).allSatisfy { self.isPrefix($0, of: $1) }
      case (.object(let p), .object(let c)):
        return p.allSatisfy { key, value in
          c[key].map { self.isPrefix(value, of: $0) } ?? false
        }
      default:
        return partial == complete
    }
  }
  
  private func snapshots(_ text: String, chunk: Int = 1) throws -> [JSON?] {
    var parser = JSONPartialParser()
    var res: [JSON?] = []
    let bytes = Array(text.utf8)
    var i = 0
    while i < bytes.count {
      try parser.append(contentsOf: bytes[i..<min(i + chunk, bytes.count)])
      res.append(try parser.snapshot())
      i += chunk
    }
    return res
  }
  
  // MARK: - Snapshots
  
  func testExample() throws {
    var parser = JSONPartialParser()
    XCTAssertNil(try parser.snapshot())
    try parser.append(#"{"city": "Par"#)
    XCTAssertEqual(try parser.snapshot(), ["city": "Par"])
    try parser.append(#"is", "population": 21"#)
    XCTAssertEqual(try parser.snapshot(), ["city": "Paris"])
    XCTAssertFalse(parser.isComplete)
    try parser.append("00000}")
    XCTAssertTrue(parser.isComplete)
    XCTAssertEqual(try parser.snapshot(), ["city": "Paris", "population": 2100000])
    XCTAssertEqual(try parser.finish(), ["city": "Paris", "population": 2100000])
  }
  
  func testObjectsAndKeys() throws {
    let snaps = try self.snapshots(#"{"ab": 1, "c"#)
    XCTAssertEqual(snaps.count, 12)
    XCTAssertEqual(snaps[0], [:])
    XCTAssertEqual(snaps[5], [:])        // {"ab"
    XCTAssertEqual(snaps[6], [:])        // {"ab":
    XCTAssertEqual(snaps[7], [:])        // {"ab": 1  (number not trusted yet)
    XCTAssertEqual(snaps[8], ["ab": 1])  // {"ab": 1,
    XCTAssertEqual(snaps[11], ["ab": 1]) // ..."c
  }
  
  func testArrays() throws {
    let snaps = try self.snapshots("[1, [2, 3], true, nu")
    XCTAssertEqual(snaps.first!, [])
    XCTAssertEqual(snaps.last!, [1, [2, 3], true])
    XCTAssertEqual(try self.snapshots("[tru").last!, [])
    XCTAssertEqual(try self.snapshots("[true").last!, [true])
    XCTAssertEqual(try self.snapshots("[1, 2").last!, [1])
    XCTAssertEqual(try self.snapshots("[1, 2,").last!, [1, 2])
  }
  
  func testStringEscapes() throws {
    XCTAssertEqual(try self.snapshots(#"["a\"#).last!, ["a"])
    XCTAssertEqual(try self.snapshots(#"["a\n"#).last!, ["a\n"])
    XCTAssertEqual(try self.snapshots(#"["a\u00"#).last!, ["a"])
    XCTAssertEqual(try self.snapshots(#"["a\u00e9"#).last!, ["aé"])
    // High surrogates need to wait for their low surrogate
    XCTAssertEqual(try self.snapshots(#"["a\ud83d"#).last!, ["a"])
    XCTAssertEqual(try self.snapshots(#"["a\ud83d\ude00"#).last!, ["a😀"])
  }
  
  func testMultibyteCharacters() throws {
    // Fragments may end in the middle of a UTF-8 sequence
    let text = "[\"héllo wörld 😀 done\"]"
    let bytes = Array(text.utf8)
    for i in 1..<bytes.count {
      var parser = JSONPartialParser()
      try parser.append(contentsOf: bytes[..<i])
      _ = try XCTUnwrap(try parser.snapshot())
      try parser.append(contentsOf: bytes[i...])
      XCTAssertEqual(try parser.finish(), ["héllo wörld 😀 done"])
    }
  }
  
  func testTopLevelValues() throws {
    XCTAssertEqual(try self.snapshots(#""abc"#).last!, "abc")
    XCTAssertNil(try self.snapshots("12").last!)
    XCTAssertNil(try self.snapshots("tr").last!)
    XCTAssertEqual(try self.snapshots("true").last!, true)
    var parser = JSONPartialParser()
    try parser.append("123")
    XCTAssertFalse(parser.isComplete)
    XCTAssertEqual(try parser.finish(), 123)
    XCTAssertEqual(try self.snapshots("  \n [] \n").last!, [])
  }
  
  // MARK: - Errors
  
  func testErrors() throws {
    for input in ["]", "{]", "[}", "[1 2]", "[,]", "[1,,2]", "{\"a\" 1}", "{1: 2}", "{\"a\": }",
                  "tru!", "nul1", "[1] 2", "\"a\u{0001}\"", "[01]", "[1.]", "[-]", "[1e]",
                  "\"a\\x\"", "\"\\u00zz\"", "{\"a\":1,}", "x"] {
      var parser = JSONPartialParser()
      XCTAssertThrowsError(try parser.append(input), input)
    }
  }
  
  func testErrorsAreSticky() throws {
    var parser = JSONPartialParser()
    XCTAssertThrowsError(try parser.append("[1 2"))
    XCTAssertThrowsError(try parser.append("]"))
    XCTAssertThrowsError(try parser.snapshot())
    XCTAssertThrowsError(try parser.finish())
  }
  
  func testTruncation() throws {
    var parser = JSONPartialParser()
    try parser.append(#"{"a": [1, 2"#)
    XCTAssertThrowsError(try parser.finish()) { error in
      XCTAssertEqual(error as? JSON.StreamError, .truncated(offset: 11))
    }
    var empty = JSONPartialParser()
    XCTAssertThrowsError(try empty.finish())
  }
  
  // MARK: - Real-world data
  
  func testPrefixesOfRealDocuments() throws {
    let url = try XCTUnwrap(self.dataURL("twitter.json"))
    let tweets = try XCTUnwrap(JSON(data: try Data(contentsOf: url)).statuses?.arrayValue)
    for (n, tweet) in tweets.prefix(6).enumerated() {
      let text = String(decoding: try tweet.data(formatting: [.sortedKeys]), as: UTF8.self)
      let bytes = Array(text.utf8)
      var parser = JSONPartialParser()
      var previous: JSON? = nil
      var i = 0
      let step = n % 2 == 0 ? 1 : 17
      while i < bytes.count {
        let end = min(i + step, bytes.count)
        try parser.append(contentsOf: bytes[i..<end])
        i = end
        if let snapshot = try parser.snapshot() {
          XCTAssertTrue(self.isPrefix(snapshot, of: tweet), "tweet \(n) at \(i)")
          if let previous {
            XCTAssertTrue(self.isPrefix(previous, of: snapshot), "tweet \(n) at \(i)")
          }
          previous = snapshot
        }
      }
      XCTAssertEqual(try parser.finish(), tweet)
      XCTAssertEqual(previous, tweet)
    }
  }
  
  func testPrettyPrintedCatalog() throws {
    let url = try XCTUnwrap(self.dataURL("citm_catalog.json"))
    let data = try Data(contentsOf: url)
    let expected = try JSON(data: data)
    var parser = JSONPartialParser()
    var i = 0
    var steps = 0
    var previous: JSON? = nil
    while i < data.count {
      let end = min(i + 40_009, data.count)
      try parser.append(contentsOf: data[i..<end])
      i = end
      if let snapshot = try parser.snapshot() {
        XCTAssertTrue(self.isPrefix(snapshot, of: expected))
        previous = snapshot
        steps += 1
      }
    }
    XCTAssertGreaterThan(steps, 30)
    XCTAssertEqual(previous, expected)
    XCTAssertEqual(try parser.finish(), expected)
  }
  
  private func dataURL(_ name: String) -> URL? {
    let bundle = Bundle(for: type(of: self))
    if let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "JSONStream") {
      return url
    }
    let url = URL(fileURLWithPath: "Tests/DynamicJSONTests/ComplianceTests/JSONStream/\(name)")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }
  
  // MARK: - Asynchronous streams
  
  func testPartialValuesStream() async throws {
    let fragments = AsyncStream<String> { continuation in
      for piece in [#"{"a": [1, "#, #"2], "b": "he"#, #"llo"}"#] {
        continuation.yield(piece)
      }
      continuation.finish()
    }
    var res: [PartialJSON] = []
    for try await partial in JSON.partialValues(from: fragments) {
      res.append(partial)
    }
    XCTAssertEqual(res, [
      PartialJSON(value: ["a": [1]], isComplete: false),
      PartialJSON(value: ["a": [1, 2], "b": "he"], isComplete: false),
      PartialJSON(value: ["a": [1, 2], "b": "hello"], isComplete: true)
    ])
    // Patches between successive snapshots
    var value = JSON.null
    var previous: PartialJSON? = nil
    for partial in res {
      try value.apply(patch: partial.patch(from: previous))
      previous = partial
    }
    XCTAssertEqual(value, res.last!.value)
  }
  
  func testPartialValuesFromBytesAndData() async throws {
    let bytes = AsyncStream<UInt8> { continuation in
      for byte in "[1, 2]".utf8 {
        continuation.yield(byte)
      }
      continuation.finish()
    }
    var last: PartialJSON? = nil
    for try await partial in JSON.partialValues(from: bytes) {
      last = partial
    }
    XCTAssertEqual(last, PartialJSON(value: [1, 2], isComplete: true))
    let chunks = AsyncStream<Data> { continuation in
      continuation.yield(Data("[tr".utf8))
      continuation.yield(Data("ue]".utf8))
      continuation.finish()
    }
    last = nil
    for try await partial in JSON.partialValues(from: chunks) {
      last = partial
    }
    XCTAssertEqual(last, PartialJSON(value: [true], isComplete: true))
  }
  
  func testPartialValuesTruncated() async throws {
    let fragments = AsyncStream<String> { continuation in
      continuation.yield(#"{"a": [1,"#)
      continuation.finish()
    }
    do {
      for try await _ in JSON.partialValues(from: fragments) {}
      XCTFail("expected error")
    } catch {
      XCTAssertTrue(error is JSON.StreamError)
    }
  }
}
