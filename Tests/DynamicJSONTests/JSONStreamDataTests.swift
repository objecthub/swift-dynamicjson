//
//  JSONStreamDataTests.swift
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

///
/// Tests the supported streaming formats with larger, real-world data. Three files from the
/// simdjson project (see `ComplianceTests/JSONStream/NOTICE.txt`) serve as a source. The
/// expected values are computed with the standard JSON decoder. The streams for all other
/// formats are derived from these values in memory.
///
final class JSONStreamDataTests: XCTestCase {
  
  enum DataError: Error {
    case fileNotFound(String)
  }
  
  // MARK: - Loading and deriving data
  
  private func url(for name: String) throws -> URL {
    let bundle = Bundle(for: type(of: self))
    if let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "JSONStream") {
      return url
    }
    let url = URL(fileURLWithPath: "Tests/DynamicJSONTests/ComplianceTests/JSONStream/\(name)")
    if FileManager.default.fileExists(atPath: url.path) {
      return url
    }
    throw DataError.fileNotFound(name)
  }
  
  private func load(_ name: String) throws -> Data {
    return try Data(contentsOf: self.url(for: name))
  }
  
  /// The lines of file `amazon_cellphones.ndjson`.
  private func cellphoneLines() throws -> [String] {
    let text = String(decoding: try self.load("amazon_cellphones.ndjson"), as: UTF8.self)
    return text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
  }
  
  /// The values of file `amazon_cellphones.ndjson`.
  private func cellphones() throws -> [JSON] {
    return try self.cellphoneLines().map { try JSON(string: $0) }
  }
  
  /// The 100 tweets of file `twitter.json`.
  private func tweets() throws -> [JSON] {
    let doc = try JSON(data: try self.load("twitter.json"))
    return try XCTUnwrap(doc.statuses?.arrayValue)
  }
  
  /// The single, pretty-printed document `citm_catalog.json`.
  private func catalog() throws -> JSON {
    return try JSON(data: try self.load("citm_catalog.json"))
  }
  
  private func compact(_ json: JSON) throws -> Data {
    return try json.data(formatting: [.sortedKeys])
  }
  
  private func pretty(_ json: JSON) throws -> Data {
    return try json.data(formatting: [.prettyPrinted, .sortedKeys])
  }
  
  /// Joins the encoded values using the given prefix, separator, and suffix.
  private func join(_ values: [JSON],
                    prefix: String = "",
                    separator: String = "",
                    suffix: String = "",
                    pretty: Bool = false) throws -> Data {
    var res = Data(prefix.utf8)
    for (i, value) in values.enumerated() {
      res.append(try pretty ? self.pretty(value) : self.compact(value))
      res.append(contentsOf: (i < values.count - 1 ? separator : suffix).utf8)
    }
    return res
  }
  
  // MARK: - Streaming helpers
  
  private func read(_ data: Data,
                    _ format: JSON.StreamFormat,
                    _ options: JSON.StreamOptions = .init()) throws -> [JSON] {
    return try JSON.values(from: data, format: format, options: options)
  }
  
  private func readAsync(_ data: Data,
                         _ format: JSON.StreamFormat,
                         _ options: JSON.StreamOptions = .init()) async throws -> [JSON] {
    let stream = AsyncStream<UInt8> { continuation in
      for byte in data {
        continuation.yield(byte)
      }
      continuation.finish()
    }
    var res: [JSON] = []
    for try await json in JSON.values(from: stream, format: format, options: options) {
      res.append(json)
    }
    return res
  }
  
  // MARK: - NDJSON file
  
  func testNDJSONFile() throws {
    let expected = try self.cellphones()
    XCTAssertEqual(expected.count, 793)
    XCTAssertEqual(try self.read(try self.load("amazon_cellphones.ndjson"), .lines), expected)
    XCTAssertEqual(try self.read(try self.load("amazon_cellphones.ndjson"), .concatenated),
                   expected)
    XCTAssertEqual(try self.read(try self.load("amazon_cellphones.ndjson"), .automatic),
                   expected)
  }
  
  func testNDJSONFileAsync() async throws {
    let expected = try self.cellphones()
    let data = try self.load("amazon_cellphones.ndjson")
    let lines = try await self.readAsync(data, .lines)
    XCTAssertEqual(lines, expected)
    let concatenated = try await self.readAsync(data, .concatenated)
    XCTAssertEqual(concatenated, expected)
  }
  
#if os(iOS) || os(watchOS) || os(tvOS) || os(macOS)
  func testNDJSONFileFromURL() async throws {
    let expected = try self.cellphones()
    var res: [JSON] = []
    for try await json in JSON.values(contentsOf: try self.url(for: "amazon_cellphones.ndjson"),
                                      format: .lines) {
      res.append(json)
    }
    XCTAssertEqual(res, expected)
  }
#endif
  
  func testNDJSONFileLineVariants() throws {
    let expected = try self.cellphones()
    let lines = try self.cellphoneLines()
    let crlf = Data((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
    XCTAssertEqual(try self.read(crlf, .lines), expected)
    let bom = Data([0xEF, 0xBB, 0xBF]) + Data((lines.joined(separator: "\n")).utf8)
    XCTAssertEqual(try self.read(bom, .lines), expected)
    XCTAssertEqual(try self.read(bom, .automatic), expected)
  }
  
  // MARK: - Formats derived from tweets
  
  func testTweetsInAllFormats() async throws {
    let tweets = try self.tweets()
    XCTAssertEqual(tweets.count, 100)
    let streams: [(String, JSON.StreamFormat, Data)] = [
      ("lines", .lines, try self.join(tweets, separator: "\n", suffix: "\n")),
      ("sequence", .sequence, try self.join(tweets, prefix: "\u{1E}", separator: "\n\u{1E}",
                                            suffix: "\n")),
      ("sequence/pretty", .sequence, try self.join(tweets, prefix: "\u{1E}",
                                                   separator: "\n\u{1E}", suffix: "\n",
                                                   pretty: true)),
      ("concatenated", .concatenated, try self.join(tweets)),
      ("concatenated/pretty", .concatenated, try self.join(tweets, separator: "\n\n",
                                                          pretty: true)),
      ("array", .arrayElements, try self.join(tweets, prefix: "[", separator: ",", suffix: "]")),
      ("array/pretty", .arrayElements, try self.join(tweets, prefix: "[\n", separator: ",\n",
                                                    suffix: "\n]\n", pretty: true)),
      ("automatic/sequence", .automatic, try self.join(tweets, prefix: "\u{1E}",
                                                       separator: "\n\u{1E}", suffix: "\n")),
      ("automatic/concatenated", .automatic, try self.join(tweets, separator: "\n"))
    ]
    for (name, format, data) in streams {
      XCTAssertEqual(try self.read(data, format), tweets, "sync: \(name)")
      let async = try await self.readAsync(data, format)
      XCTAssertEqual(async, tweets, "async: \(name)")
    }
  }
  
  func testTweetsWithEscapedCharacters() throws {
    // Tweets contain multi-byte characters; see that they survive framing, both as UTF-8 and
    // as ASCII-only text using `\u` escapes (including surrogate pairs).
    let tweets = try self.tweets()
    let text = String(decoding: try self.join(tweets, separator: "\n"), as: UTF8.self)
    XCTAssertTrue(text.utf8.count > text.count)
    XCTAssertEqual(try self.read(Data(text.utf8), .lines), tweets)
    var ascii = ""
    for scalar in text.unicodeScalars {
      if scalar.isASCII {
        ascii.unicodeScalars.append(scalar)
      } else {
        for unit in String(scalar).utf16 {
          ascii += "\\u" + String(format: "%04x", unit)
        }
      }
    }
    XCTAssertTrue(ascii.utf8.count == ascii.count)
    XCTAssertTrue(ascii.contains("\\ud83d"))
    XCTAssertEqual(try self.read(Data(ascii.utf8), .lines), tweets)
    XCTAssertEqual(try self.read(Data(ascii.utf8), .concatenated), tweets)
  }
  
  // MARK: - Large pretty-printed documents
  
  func testCatalogConcatenated() async throws {
    let catalog = try self.catalog()
    let original = try self.load("citm_catalog.json")
    XCTAssertEqual(try self.read(original, .concatenated), [catalog])
    XCTAssertEqual(try self.read(original, .automatic), [catalog])
    let async = try await self.readAsync(original, .concatenated)
    XCTAssertEqual(async, [catalog])
    // Several copies, with and without separators
    let three = [catalog, catalog, catalog]
    XCTAssertEqual(try self.read(try self.join(three), .concatenated), three)
    XCTAssertEqual(try self.read(try self.join(three, separator: "\n\n", pretty: true),
                                 .concatenated), three)
    let sequence = try self.join(three, prefix: "\u{1E}", separator: "\n\u{1E}", suffix: "\n",
                                 pretty: true)
    XCTAssertEqual(try self.read(sequence, .sequence), three)
  }
  
  func testCatalogIsNotValidAsLines() throws {
    XCTAssertThrowsError(try self.read(try self.load("citm_catalog.json"), .lines))
  }
  
  // MARK: - Errors
  
  func testCorruptedLines() throws {
    let expected = try self.cellphones()
    var lines = try self.cellphoneLines()
    var survivors: [JSON] = []
    var firstOffset: Int? = nil
    var offset = 0
    for i in lines.indices {
      if i % 50 == 25 {
        if firstOffset == nil {
          firstOffset = offset
        }
        lines[i] = "{oops " + lines[i]
      } else {
        survivors.append(expected[i])
      }
      offset += lines[i].utf8.count + 1
    }
    let data = Data((lines.joined(separator: "\n") + "\n").utf8)
    XCTAssertEqual(try self.read(data, .lines, .init(errors: .skipInvalid)), survivors)
    XCTAssertThrowsError(try self.read(data, .lines)) { error in
      guard case .invalidValue(let offset, _) = error as? JSON.StreamError else {
        return XCTFail("unexpected error \(error)")
      }
      XCTAssertEqual(offset, firstOffset)
    }
    let results = Array(JSON.results(from: data, format: .lines))
    XCTAssertEqual(results.count, expected.count)
    XCTAssertEqual(results.filter { if case .failure(_) = $0 { return true } else { return false } }.count,
                   expected.count - survivors.count)
  }
  
  func testCorruptedRecords() async throws {
    let tweets = try self.tweets()
    var survivors: [JSON] = []
    var data = Data()
    for (i, tweet) in tweets.enumerated() {
      data.append(0x1E)
      if i % 10 == 3 {
        data.append(contentsOf: "{\"broken\": [1, 2,\n".utf8)
      } else {
        data.append(try self.compact(tweet))
        data.append(0x0A)
        survivors.append(tweet)
      }
    }
    XCTAssertEqual(try self.read(data, .sequence, .init(errors: .skipInvalid)), survivors)
    let async = try await self.readAsync(data, .sequence, .init(errors: .skipInvalid))
    XCTAssertEqual(async, survivors)
    XCTAssertThrowsError(try self.read(data, .sequence))
  }
  
  func testTruncatedStream() throws {
    let data = try self.join(try self.tweets(), prefix: "[", separator: ",", suffix: "]")
    let truncated = data.prefix(data.count - 1000)
    XCTAssertThrowsError(try self.read(Data(truncated), .arrayElements)) { error in
      guard case .truncated(_)? = error as? JSON.StreamError else {
        return XCTFail("unexpected error \(error)")
      }
    }
  }
  
  func testMaxValueSize() throws {
    let data = try self.load("amazon_cellphones.ndjson")
    let expected = try self.cellphones()
    let largest = try self.cellphoneLines().map { $0.utf8.count }.max()!
    XCTAssertEqual(try self.read(data, .lines, .init(maxValueSize: largest)), expected)
    XCTAssertEqual(try self.read(data, .concatenated, .init(maxValueSize: largest)), expected)
    XCTAssertThrowsError(try self.read(data, .lines, .init(maxValueSize: largest - 1))) { error in
      guard case .valueTooLarge(_)? = error as? JSON.StreamError else {
        return XCTFail("unexpected error \(error)")
      }
    }
    XCTAssertThrowsError(try self.read(data, .concatenated, .init(maxValueSize: largest - 1)))
    // `valueTooLarge` is fatal, even when skipping invalid values
    XCTAssertThrowsError(try self.read(data,
                                       .lines,
                                       .init(errors: .skipInvalid, maxValueSize: largest - 1)))
  }
  
  // MARK: - Performance
  
  func testPerformanceOfLargeDocument() throws {
    let data = try self.load("citm_catalog.json")
    self.measure {
      let values = try? self.read(data, .concatenated)
      XCTAssertEqual(values?.count, 1)
    }
  }
}
