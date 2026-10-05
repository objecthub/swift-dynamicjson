//
//  JSONStreamTests.swift
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

final class JSONStreamTests: XCTestCase {
  
  private func bytes(_ str: String) -> [UInt8] {
    return Array(str.utf8)
  }
  
  private func values(_ str: String,
                      _ format: JSON.StreamFormat,
                      _ options: JSON.StreamOptions = .init()) throws -> [JSON] {
    let sync = try JSON.values(from: self.bytes(str), format: format, options: options)
    return sync
  }
  
  private func asyncValues(_ str: String,
                           _ format: JSON.StreamFormat,
                           _ options: JSON.StreamOptions = .init()) async throws -> [JSON] {
    var res: [JSON] = []
    let stream = AsyncStream<UInt8> { cont in
      for b in str.utf8 {
        cont.yield(b)
      }
      cont.finish()
    }
    for try await json in JSON.values(from: stream, format: format, options: options) {
      res.append(json)
    }
    return res
  }
  
  // MARK: - Lines
  
  func testLines() throws {
    let input = "{\"a\":1}\r\n\n  \n[1,2]\n\"x\"\n42\ntrue\nnull"
    let expected: [JSON] = [["a": 1], [1, 2], "x", 42, true, nil]
    XCTAssertEqual(try self.values(input, .lines), expected)
  }
  
  func testLinesByteOrderMark() throws {
    XCTAssertEqual(try self.values("\u{FEFF}{\"a\":1}\n2\n", .lines), [["a": 1], 2])
  }
  
  func testLinesSkipInvalid() throws {
    let input = "1\n{oops\n3\n"
    XCTAssertThrowsError(try self.values(input, .lines))
    XCTAssertEqual(try self.values(input, .lines, .init(errors: .skipInvalid)), [1, 3])
  }
  
  func testResults() throws {
    let results = Array(JSON.results(from: self.bytes("1\n{oops\n3\n"), format: .lines))
    XCTAssertEqual(results.count, 3)
    XCTAssertEqual(try results[0].get(), 1)
    guard case .failure(.invalidValue(let offset, _)) = results[1] else {
      return XCTFail("expected invalid value")
    }
    XCTAssertEqual(offset, 2)
    XCTAssertEqual(try results[2].get(), 3)
  }
  
  // MARK: - RFC 7464
  
  func testSequence() throws {
    let input = "\u{1E}{\"a\":1}\n\u{1E}[1,\n2]\n\u{1E}\"s\"\n\u{1E}12\n\u{1E}true\n"
    XCTAssertEqual(try self.values(input, .sequence),
                   [["a": 1], [1, 2], "s", 12, true])
  }
  
  func testSequenceRepeatedSeparators() throws {
    XCTAssertEqual(try self.values("\u{1E}\u{1E}\u{1E}1\n\u{1E}\n\u{1E}2\n", .sequence), [1, 2])
  }
  
  func testSequenceTruncatedScalarsAreDropped() throws {
    // RFC 7464, section 2.4: texts like `1` that are not followed by whitespace are dropped.
    XCTAssertEqual(try self.values("\u{1E}1\n\u{1E}23\u{1E}true\n\u{1E}fals", .sequence), [1, true])
  }
  
  func testSequenceRecovery() throws {
    let input = "\u{1E}{\"a\":\n\u{1E}3\n"
    XCTAssertThrowsError(try self.values(input, .sequence))
    XCTAssertEqual(try self.values(input, .sequence, .init(errors: .skipInvalid)), [3])
  }
  
  // MARK: - Concatenated JSON
  
  func testConcatenated() throws {
    let input = #"{"a":"}{"}[1,[2]]"x\"]" 5 6 true{"b":null}"#
    XCTAssertEqual(try self.values(input, .concatenated),
                   [["a": "}{"], [1, [2]], "x\"]", 5, 6, true, ["b": nil]])
  }
  
  func testConcatenatedScalarAtEnd() throws {
    XCTAssertEqual(try self.values("1 2 3", .concatenated), [1, 2, 3])
  }
  
  func testConcatenatedTruncated() throws {
    XCTAssertThrowsError(try self.values("{\"a\": [1,", .concatenated)) { error in
      XCTAssertEqual(error as? JSON.StreamError, .truncated(offset: 0))
    }
  }
  
  func testConcatenatedStrayBytes() throws {
    XCTAssertThrowsError(try self.values("1 ] 2", .concatenated))
    XCTAssertEqual(try self.values("1 ] 2", .concatenated, .init(errors: .skipInvalid)), [1, 2])
  }
  
  // MARK: - Automatic detection
  
  func testAutomatic() throws {
    XCTAssertEqual(try self.values("\n \u{1E}1\n\u{1E}2\n", .automatic), [1, 2])
    XCTAssertEqual(try self.values("{\"a\":1}\n{\"b\":2}\n", .automatic), [["a": 1], ["b": 2]])
    XCTAssertEqual(try self.values("[1,2][3]", .automatic), [[1, 2], [3]])
    XCTAssertEqual(try self.values("", .automatic), [])
    XCTAssertEqual(try self.values("  \n", .automatic), [])
  }
  
  // MARK: - Array elements
  
  func testArrayElements() throws {
    let input = " [ 1 , {\"a\":[1,2]}, \"x,]\", [3, [4]], true,null ] \n"
    XCTAssertEqual(try self.values(input, .arrayElements),
                   [1, ["a": [1, 2]], "x,]", [3, [4]], true, nil])
  }
  
  func testArrayElementsEmpty() throws {
    XCTAssertEqual(try self.values("[]", .arrayElements), [])
    XCTAssertEqual(try self.values("  [ ] ", .arrayElements), [])
    XCTAssertEqual(try self.values("", .arrayElements), [])
  }
  
  func testArrayElementsErrors() throws {
    XCTAssertThrowsError(try self.values("{}", .arrayElements)) { error in
      XCTAssertEqual(error as? JSON.StreamError, .expectedArray(offset: 0))
    }
    XCTAssertThrowsError(try self.values("[1,]", .arrayElements))
    XCTAssertThrowsError(try self.values("[,1]", .arrayElements))
    XCTAssertThrowsError(try self.values("[1 2]", .arrayElements))
    XCTAssertThrowsError(try self.values("[1, 2", .arrayElements)) { error in
      XCTAssertEqual(error as? JSON.StreamError, .truncated(offset: 5))
    }
    XCTAssertThrowsError(try self.values("[1] 2", .arrayElements))
  }
  
  // MARK: - Limits and string input
  
  func testMaxValueSize() throws {
    let options = JSON.StreamOptions(errors: .skipInvalid, maxValueSize: 5)
    XCTAssertEqual(try self.values("[1]\n[2]\n", .lines, options), [[1], [2]])
    XCTAssertThrowsError(try self.values("[1]\n[2,3,4]\n[5]\n", .lines, options)) { error in
      XCTAssertEqual(error as? JSON.StreamError, .valueTooLarge(offset: 4))
    }
    XCTAssertThrowsError(try self.values("[1,2,3,4,5]", .concatenated, options))
    // The limit also applies to the last byte of a value
    XCTAssertEqual(try self.values("[1,2,3]", .concatenated, .init(maxValueSize: 7)), [[1, 2, 3]])
    XCTAssertThrowsError(try self.values("[1,2,3]", .concatenated, .init(maxValueSize: 6)))
    XCTAssertThrowsError(try self.values("[[1,2,3]]", .arrayElements, .init(maxValueSize: 6)))
  }
  
  func testStringInput() throws {
    XCTAssertEqual(try JSON.values(from: "{\"a\":1}\n{\"b\":2}\n", format: .lines),
                   [["a": 1], ["b": 2]])
  }
  
  // MARK: - Asynchronous streams
  
  func testAsyncMatchesSync() async throws {
    let inputs: [(String, JSON.StreamFormat)] = [
      ("1\n{\"a\":[1,2]}\n\"x\"\n", .lines),
      ("\u{1E}1\n\u{1E}[2,3]\n", .sequence),
      ("{\"a\":1}[2]3 4", .concatenated),
      ("[1,[2],{\"a\":3}]", .arrayElements),
      ("\u{FEFF}7 8", .automatic)
    ]
    for (input, format) in inputs {
      let a = try await self.asyncValues(input, format)
      let s = try self.values(input, format)
      XCTAssertEqual(a, s)
      XCTAssertFalse(a.isEmpty)
    }
  }
  
  func testAsyncErrors() async throws {
    do {
      _ = try await self.asyncValues("1\n{oops\n3\n", .lines)
      XCTFail("expected error")
    } catch {
      XCTAssertTrue(error is JSON.StreamError)
    }
    let skipped = try await self.asyncValues("1\n{oops\n3\n", .lines, .init(errors: .skipInvalid))
    XCTAssertEqual(skipped, [1, 3])
  }
  
  func testAsyncResults() async throws {
    let stream = AsyncStream<UInt8> { cont in
      for b in "1\n{oops\n3\n".utf8 {
        cont.yield(b)
      }
      cont.finish()
    }
    var successes = 0
    var failures = 0
    for try await result in JSON.results(from: stream, format: .lines) {
      switch result {
        case .success(_):
          successes += 1
        case .failure(_):
          failures += 1
      }
    }
    XCTAssertEqual(successes, 2)
    XCTAssertEqual(failures, 1)
  }
  
  func testFileStream() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).ndjson")
    try "{\"a\":1}\n{\"a\":2}\n".write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }
    var res: [JSON] = []
    for try await json in JSON.values(contentsOf: url, format: .lines) {
      res.append(json)
    }
    XCTAssertEqual(res, [["a": 1], ["a": 2]])
  }
}
