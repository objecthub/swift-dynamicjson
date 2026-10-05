//
//  JSONLenientTests.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 06/10/2026.
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

final class JSONLenientTests: XCTestCase {
  
  private func lenient(_ text: String, truncation: Bool = true) throws -> JSON {
    return try JSON(lenient: text, repairTruncation: truncation)
  }
  
  private func repairs(_ text: String) throws -> Set<JSONRepair> {
    let results = JSON.extract(from: text)
    XCTAssertEqual(results.count, 1, text)
    return results.first?.repairs ?? []
  }
  
  // MARK: - Strict JSON
  
  func testStrictJSON() throws {
    let text = #"{"a": [1, 2.5, -3, 1e3, "x\né😀", true, false, null], "b": {}}"#
    let expected = try JSON(string: text)
    XCTAssertEqual(try self.lenient(text), expected)
    let results = JSON.extract(from: "Result: \(text) Done.")
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].value, expected)
    XCTAssertTrue(results[0].isStrict)
  }
  
  func testScalars() throws {
    XCTAssertEqual(try self.lenient("  42 "), 42)
    XCTAssertEqual(try self.lenient("\"hi\""), "hi")
    XCTAssertEqual(try self.lenient("true"), true)
    XCTAssertEqual(try self.lenient("-1.5e2"), try JSON(string: "-1.5e2"))
    XCTAssertEqual(try self.lenient("12345678901234567890"), .float(12345678901234567890.0))
  }
  
  // MARK: - Repairs
  
  func testTrailingCommas() throws {
    XCTAssertEqual(try self.lenient("[1, 2, 3,]"), [1, 2, 3])
    XCTAssertEqual(try self.lenient(#"{"a": 1, "b": [1,], }"#), ["a": 1, "b": [1]])
    XCTAssertEqual(try self.repairs("[1,]"), [.trailingComma])
  }
  
  func testMissingCommas() throws {
    XCTAssertEqual(try self.lenient(#"{"a": 1 "b": 2}"#), ["a": 1, "b": 2])
    XCTAssertEqual(try self.repairs(#"{"a": 1 "b": 2}"#), [.missingComma])
    XCTAssertThrowsError(try self.lenient("[1 2]"))
  }
  
  func testComments() throws {
    let text = """
      {
        // the name
        "name": "x", /* inline */ "n": 1
        /* trailing
           comment */
      }
      """
    XCTAssertEqual(try self.lenient(text), ["name": "x", "n": 1])
    XCTAssertEqual(try self.repairs(text), [.comment])
  }
  
  func testSingleQuotesAndUnquotedKeys() throws {
    XCTAssertEqual(try self.lenient("{name: 'Ada', 'age': 36, first-name: \"x\"}"),
                   ["name": "Ada", "age": 36, "first-name": "x"])
    XCTAssertEqual(try self.lenient(#"{'a': 'it\'s "quoted"'}"#), ["a": #"it's "quoted""#])
    XCTAssertEqual(try self.repairs("{a: 'x'}"), [.unquotedKey, .singleQuotedString])
  }
  
  func testLiterals() throws {
    XCTAssertEqual(try self.lenient("[True, False, None, NULL, nil, undefined]"),
                   [true, false, nil, nil, nil, nil])
    XCTAssertEqual(try self.repairs("[True]"), [.nonStandardLiteral])
    XCTAssertEqual(try self.repairs("[true, null]"), [])
  }
  
  func testNumbers() throws {
    XCTAssertEqual(try self.lenient("[+1, .5, 5., 007, -.25, 0x1F, 1.e2]"),
                   try JSON(string: "[1, 0.5, 5.0, 7, -0.25, 31, 1.0e2]"))
    XCTAssertEqual(try self.repairs("[.5]"), [.nonStandardNumber])
    XCTAssertEqual(try self.lenient("[NaN, Infinity, -Infinity]"), [nil, nil, nil])
    XCTAssertEqual(try self.repairs("[NaN]"), [.nonFiniteNumber])
    XCTAssertThrowsError(try self.lenient("[1.2.3]"))
    XCTAssertThrowsError(try self.lenient("[12abc]"))
    XCTAssertThrowsError(try self.lenient("[-]"))
  }
  
  func testStrings() throws {
    // Raw line breaks and tabs, unknown escapes, and broken surrogates
    XCTAssertEqual(try self.lenient("\"line1\nline2\tx\""), "line1\nline2\tx")
    XCTAssertEqual(try self.repairs("[\"a\nb\"]"), [.rawControlCharacter])
    XCTAssertEqual(try self.lenient(#""a\qb""#), "aqb")
    XCTAssertEqual(try self.repairs(#"["a\qb"]"#), [.invalidEscape])
    XCTAssertEqual(try self.lenient(#""😀 \ud83d x \ude00""#), "😀 \u{FFFD} x \u{FFFD}")
    XCTAssertEqual(try self.lenient(#""\u00""#), "u00")
  }
  
  // MARK: - Truncation
  
  func testTruncation() throws {
    XCTAssertEqual(try self.lenient(#"{"a": [1, 2, {"b": "hel"#), ["a": [1, 2, ["b": "hel"]]])
    XCTAssertEqual(try self.lenient(#"{"a": 1, "b""#), ["a": 1])
    XCTAssertEqual(try self.lenient(#"{"a": 1, "b":"#), ["a": 1])
    XCTAssertEqual(try self.lenient(#"{"a": 1, "b": tru"#), ["a": 1])
    XCTAssertEqual(try self.lenient(#"{"a": 1, "b": nul"#), ["a": 1])
    XCTAssertEqual(try self.lenient(#"[1, 2, "ab\"#), [1, 2, "ab"])
    XCTAssertEqual(try self.lenient(#"["a\u12"#), ["a"])
    XCTAssertEqual(try self.lenient(#"{"a": 12"#), ["a": 12])
    XCTAssertEqual(try self.lenient(#"[1, // comment"#), [1])
    XCTAssertEqual(try self.repairs(#"[1, 2"#), [.truncated])
    XCTAssertThrowsError(try self.lenient("", truncation: true))
    XCTAssertThrowsError(try self.lenient("   "))
    XCTAssertThrowsError(try self.lenient("[1, 2", truncation: false)) { error in
      XCTAssertEqual(error as? JSON.LenientError, .unexpectedEnd(offset: 5))
    }
    XCTAssertThrowsError(try self.lenient(#"{"a": "x"#, truncation: false))
  }
  
  // MARK: - Errors
  
  func testErrors() throws {
    for text in ["", "]", "{]", "{1: 2}", #"{"a" 1}"#, "[1,, 2]", "[,]", "{,}", "hello", "{a b}",
                 "[1] 2", "{\"a\": 1} {\"b\": 2}", ":"] {
      XCTAssertThrowsError(try self.lenient(text), text)
    }
    XCTAssertThrowsError(try self.lenient("[1] x")) { error in
      XCTAssertEqual(error as? JSON.LenientError, .trailingContent(offset: 4))
    }
    let deep = String(repeating: "[", count: 300)
    XCTAssertThrowsError(try self.lenient(deep)) { error in
      guard case .tooDeeplyNested(_)? = error as? JSON.LenientError else {
        return XCTFail("unexpected error \(error)")
      }
    }
    // Extraction does not give up on the text, but finds the innermost part that is usable
    XCTAssertEqual(JSON.extract(from: deep).count, 1)
  }
  
  // MARK: - Code blocks
  
  func testFencedBlock() throws {
    XCTAssertEqual(try self.lenient("```json\n{\"a\": 1,}\n```"), ["a": 1])
    XCTAssertEqual(try self.lenient("\n  ```\n[1, 2]\n```  \n"), [1, 2])
    XCTAssertEqual(try self.lenient("~~~jsonc\n{\"a\": 1} // x\n~~~"), ["a": 1])
    XCTAssertEqual(try self.lenient("```json\n{\"a\": 1, \"b\": [1"), ["a": 1, "b": [1]])
    XCTAssertThrowsError(try self.lenient("Here: ```json\n{}\n```"))
  }
  
  // MARK: - Extraction from text
  
  func testExtractFromResponse() throws {
    let answer = """
      Sure! Here is the data you asked for:
      
      ```json
      {
        "name": "Ada",   // the first programmer
        "languages": ["en", "fr",],
      }
      ```
      
      And here is a second object, inline: {'x': 1, y: None}. Let me know if you need
      anything else, see also [1] and { not json }.
      """
    let results = JSON.extract(from: answer)
    XCTAssertEqual(results.count, 3)
    XCTAssertEqual(results[0].value, ["name": "Ada", "languages": ["en", "fr"]])
    XCTAssertEqual(results[0].source, .fencedBlock(language: "json"))
    XCTAssertEqual(results[0].repairs, [.comment, .trailingComma])
    XCTAssertFalse(results[0].isStrict)
    XCTAssertEqual(results[1].value, ["x": 1, "y": nil])
    XCTAssertEqual(results[1].source, .text)
    XCTAssertEqual(String(answer[results[1].range]), "{'x': 1, y: None}")
    XCTAssertEqual(results[2].value, [1])
    XCTAssertEqual(String(answer[results[2].range]), "[1]")
    // Options
    let objects = JSON.extract(from: answer, options: .init(types: [.object]))
    XCTAssertEqual(objects.count, 2)
    let fenced = JSON.extract(from: answer, options: .init(scope: .fencedBlocks))
    XCTAssertEqual(fenced.count, 1)
    XCTAssertEqual(JSON.extract(from: answer, options: .init(maxCount: 2)).count, 2)
    XCTAssertEqual(JSON.extractFirst(from: answer)?.value,
                   ["name": "Ada", "languages": ["en", "fr"]])
  }
  
  func testExtractMultipleBlocks() throws {
    let text = """
      First:
      ```json
      {"a": 1}
      ```
      Second, with other language tags and several values in one block:
      ```javascript
      {"b": 2}
      [3]
      ```
      ```
      {"c": 3
      ```
      """
    let results = JSON.extract(from: text)
    XCTAssertEqual(results.map { $0.value }, [["a": 1], ["b": 2], [3], ["c": 3]])
    XCTAssertEqual(results.map { $0.source }, [.fencedBlock(language: "json"),
                                               .fencedBlock(language: "javascript"),
                                               .fencedBlock(language: "javascript"),
                                               .fencedBlock(language: nil)])
  }
  
  func testNestedCandidates() throws {
    // The outer braces are not JSON, but the object inside is
    let text = #"Maybe { see {"a": [1, 2]} here } or {"b": true}"#
    XCTAssertEqual(JSON.extract(from: text).map { $0.value }, [["a": [1, 2]], ["b": true]])
    // Brackets that do not start a value are skipped
    XCTAssertTrue(JSON.extract(from: "a [ b ] c } ] { ,").isEmpty)
    XCTAssertTrue(JSON.extract(from: "").isEmpty)
  }
  
  func testExtractTruncatedOutput() throws {
    let text = #"Here you go: {"items": [{"id": 1, "tags": ["a", "b"]}, {"id": 2, "tags": ["c"#
    let results = JSON.extract(from: text)
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].value, ["items": [["id": 1, "tags": ["a", "b"]],
                                                ["id": 2, "tags": ["c"]]]])
    XCTAssertEqual(results[0].repairs, [.truncated])
    // Without repairing truncation, only the complete object inside is found
    XCTAssertEqual(JSON.extract(from: text, options: .init(repairTruncation: false)).map { $0.value },
                   [["id": 1, "tags": ["a", "b"]]])
  }
  
  func testRangesAreValid() throws {
    let text = "ünïcode 😀 first {\"é\": \"😀\"} then [1, 2] ✓ end"
    let results = JSON.extract(from: text)
    XCTAssertEqual(results.map { String(text[$0.range]) }, ["{\"é\": \"😀\"}", "[1, 2]"])
  }
  
  // MARK: - More extraction scenarios
  
  private func values(_ text: String, _ options: JSONExtractionOptions = .init()) -> [JSON] {
    return JSON.extract(from: text, options: options).map { $0.value }
  }
  
  func testNothingToExtract() throws {
    for text in ["", " \n\t ", "just words", "no braces: ) ( } ] \" '", "42 true null \"x\"",
                 "Use {{name}} placeholders", "a {\"a\": {{value}}} template", "{ } { ]"] {
      XCTAssertEqual(self.values(text), text == "{ } { ]" ? [[:]] : [], text)
    }
    XCTAssertNil(JSON.extractFirst(from: "nothing here"))
    XCTAssertEqual(self.values("{\"a\": 1}", .init(maxCount: 0)), [])
  }
  
  func testEmptyContainers() throws {
    XCTAssertEqual(self.values("x {} y [] z"), [[:], []])
    XCTAssertEqual(self.values("{ } [ ]"), [[:], []])
  }
  
  func testAdjacentValues() throws {
    XCTAssertEqual(self.values(#"{"a":1}{"b":2}"#), [["a": 1], ["b": 2]])
    XCTAssertEqual(self.values("[1][2],[3]"), [[1], [2], [3]])
    XCTAssertEqual(self.values("{\"a\": 1}\n{\"b\": 2}\n{\"c\": 3}"),
                   [["a": 1], ["b": 2], ["c": 3]])
  }
  
  func testBracketsInsideStringsAndComments() throws {
    XCTAssertEqual(self.values(#"see {"a": "}{ ]", "b": "\"}"} end"#),
                   [["a": "}{ ]", "b": "\"}"]])
    XCTAssertEqual(self.values("{\"a\": 1 /* } ] */, // ]}\n \"b\": 2}"), [["a": 1, "b": 2]])
    XCTAssertEqual(self.values("{'a': 'it\\'s }'}"), [["a": "it's }"]])
  }
  
  func testInlineCodeAndOneLineFences() throws {
    let text = "Call it with `{\"a\": 1}` or ```json {\"b\": 2} ``` as you like."
    let results = JSON.extract(from: text)
    XCTAssertEqual(results.map { $0.value }, [["a": 1], ["b": 2]])
    XCTAssertEqual(results.map { $0.source }, [.text, .text])
    XCTAssertEqual(results.map { String(text[$0.range]) }, ["{\"a\": 1}", "{\"b\": 2}"])
  }
  
  func testPythonDictionary() throws {
    let results = JSON.extract(from: "Result: {'a': True, 'b': None, 'c': [1, 2], 'd': 'x'}")
    XCTAssertEqual(results.map { $0.value }, [["a": true, "b": nil, "c": [1, 2], "d": "x"]])
    XCTAssertEqual(results[0].repairs, [.singleQuotedString, .nonStandardLiteral])
  }
  
  func testDuplicateKeysAndUnicode() throws {
    XCTAssertEqual(self.values(#"{"a": 1, "a": 2}"#), [["a": 2]])
    XCTAssertEqual(self.values(#"{"ключ": "значение", "emoji": "😀 😀"}"#),
                   [["ключ": "значение", "emoji": "😀 😀"]])
  }
  
  func testMultilineString() throws {
    let results = JSON.extract(from: "Here: {\"text\": \"line 1\nline 2\"} done")
    XCTAssertEqual(results.map { $0.value }, [["text": "line 1\nline 2"]])
    XCTAssertEqual(results[0].repairs, [.rawControlCharacter])
  }
  
  func testUnbalancedDelimiters() throws {
    XCTAssertEqual(self.values("} ] ) {\"a\": 1} ] }"), [["a": 1]])
    // An unclosed array is completed, unless truncation is not repaired
    XCTAssertEqual(self.values("[ {\"a\": 1}"), [[["a": 1]]])
    XCTAssertEqual(self.values("[ {\"a\": 1}", .init(repairTruncation: false)), [["a": 1]])
    XCTAssertEqual(self.values("[1, 2, {\"a\": 1}"), [[1, 2, ["a": 1]]])
  }
  
  func testDeepNesting() throws {
    let depth = 200
    let text = "x " + String(repeating: "[", count: depth) + "1" + String(repeating: "]", count: depth)
    var expected = JSON.array([1])
    for _ in 1..<depth {
      expected = .array([expected])
    }
    XCTAssertEqual(self.values(text), [expected])
    // Many opening brackets that never close must not take quadratic time
    let pathological = String(repeating: "[", count: 50_000)
    XCTAssertEqual(self.values(pathological, .init(repairTruncation: false)), [])
  }
  
  // MARK: - Code block variants
  
  func testFenceVariants() throws {
    // A longer fence can contain shorter ones
    let nested = "````markdown\n```json\n{\"a\": 1}\n```\n````"
    XCTAssertEqual(self.values(nested), [["a": 1]])
    XCTAssertEqual(JSON.extract(from: nested)[0].source, .fencedBlock(language: "markdown"))
    // Fences may be indented by up to three spaces, and the info string can have several words
    let indented = "   ```json title=\"data\"\n   {\"a\": 1}\n   ```"
    XCTAssertEqual(JSON.extract(from: indented)[0].source, .fencedBlock(language: "json"))
    XCTAssertEqual(self.values(indented), [["a": 1]])
    // A closing fence can be longer than the opening fence, and tildes are fences as well
    XCTAssertEqual(self.values("```\n[1]\n`````\nafter"), [[1]])
    XCTAssertEqual(self.values("~~~~\n[1]\n~~~~~"), [[1]])
    // A closing fence needs the same marker
    XCTAssertEqual(JSON.extract(from: "```json\n{\"a\": 1}\n~~~\n{\"b\": 2}\n```").map { $0.value },
                   [["a": 1], ["b": 2]])
  }
  
  func testWindowsLineEndings() throws {
    let text = "Intro\r\n```json\r\n{\"a\": [1, 2]}\r\n```\r\nOutro {\"b\": 1}\r\n"
    let results = JSON.extract(from: text)
    XCTAssertEqual(results.map { $0.value }, [["a": [1, 2]], ["b": 1]])
    XCTAssertEqual(results.map { $0.source }, [.fencedBlock(language: "json"), .text])
    XCTAssertEqual(try JSON(lenient: "```json\r\n{\"a\": 1}\r\n```"), ["a": 1])
  }
  
  func testUnclosedFence() throws {
    let text = "Here:\n```json\n{\"a\": 1,\n \"b\": [1, 2"
    let results = JSON.extract(from: text)
    XCTAssertEqual(results.map { $0.value }, [["a": 1, "b": [1, 2]]])
    XCTAssertEqual(results[0].repairs, [.truncated])
    XCTAssertEqual(results[0].source, .fencedBlock(language: "json"))
  }
  
  func testScopeAndTypes() throws {
    let text = "Inline {\"a\": 1}.\n```json\n42\n```\n```\n\"hello\"\n```\n```\n{\"b\": 2}\n```"
    XCTAssertEqual(self.values(text), [["a": 1], ["b": 2]])
    XCTAssertEqual(self.values(text, .init(scope: .fencedBlocks)), [["b": 2]])
    // Scalars are only extracted from code blocks that consist of nothing but the scalar
    XCTAssertEqual(self.values(text, .init(types: [.number])), [42])
    XCTAssertEqual(self.values(text, .init(types: [.string])), ["hello"])
    XCTAssertEqual(self.values(text, .init(types: [.object, .integer, .string])),
                   [["a": 1], 42, "hello", ["b": 2]])
    XCTAssertEqual(self.values(text, .init(types: [])), [])
  }
  
  func testMixedOrderAndExtractFirst() throws {
    let text = """
      First {"a": 1} inline,
      then a block:
      ```json
      {"b": 2}
      ```
      and finally [3].
      """
    let results = JSON.extract(from: text)
    XCTAssertEqual(results.map { $0.value }, [["a": 1], ["b": 2], [3]])
    XCTAssertEqual(results.map { $0.source }, [.text, .fencedBlock(language: "json"), .text])
    // Ranges are in increasing order and do not overlap
    for (first, second) in zip(results, results.dropFirst()) {
      XCTAssertLessThanOrEqual(first.range.upperBound, second.range.lowerBound)
    }
    XCTAssertEqual(JSON.extractFirst(from: text)?.value, ["a": 1])
    XCTAssertEqual(JSON.extractFirst(from: text, options: .init(scope: .fencedBlocks))?.value,
                   ["b": 2])
  }
  
  func testRepairsOfSeveralKinds() throws {
    let text = """
      {
        name: 'Ada',            // unquoted key, single quotes, comment
        "born": 1815,
        "tags": ["math", "poetry",],
        "alive": False,
        "score": .5,
        "ratio": NaN
      """
    let result = try XCTUnwrap(JSON.extract(from: text).first)
    XCTAssertEqual(result.value,
                   try JSON(string: #"{"name":"Ada","born":1815,"tags":["math","poetry"],"alive":false,"score":0.5,"ratio":null}"#))
    XCTAssertEqual(result.repairs, [.unquotedKey, .singleQuotedString, .comment, .trailingComma,
                                    .nonStandardLiteral, .nonStandardNumber, .nonFiniteNumber,
                                    .truncated])
    XCTAssertFalse(result.isStrict)
  }
  
  func testStrictValuesHaveNoRepairs() throws {
    let results = JSON.extract(from: #"Data: {"a": [1, 2.5, "x"], "b": null} and [true]"#)
    XCTAssertEqual(results.count, 2)
    XCTAssertTrue(results.allSatisfy { $0.isStrict })
  }
  
  func testRangesWithMultibyteText() throws {
    let text = "日本語 🎉 {\"k\": \"é\"} → [1] 🎉🎉 {\"z\": []}"
    let results = JSON.extract(from: text)
    XCTAssertEqual(results.map { String(text[$0.range]) }, ["{\"k\": \"é\"}", "[1]", "{\"z\": []}"])
    // The text before and after a range can be recovered
    XCTAssertEqual(String(text[..<results[0].range.lowerBound]), "日本語 🎉 ")
  }
  
  // MARK: - Real-world data
  
  private func dataURL(_ name: String) throws -> URL {
    let bundle = Bundle(for: type(of: self))
    if let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "JSONStream") {
      return url
    }
    return URL(fileURLWithPath: "Tests/DynamicJSONTests/ComplianceTests/JSONStream/\(name)")
  }
  
  func testLenientMatchesStrictParser() throws {
    let data = try Data(contentsOf: self.dataURL("twitter.json"))
    let expected = try JSON(data: data)
    let text = String(decoding: data, as: UTF8.self)
    XCTAssertEqual(try self.lenient(text), expected)
    let results = JSON.extract(from: "Here is a lot of data:\n\n\(text)\n\nEnd.")
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].value, expected)
    XCTAssertTrue(results[0].isStrict)
    let catalog = try Data(contentsOf: self.dataURL("citm_catalog.json"))
    XCTAssertEqual(try self.lenient(String(decoding: catalog, as: UTF8.self)),
                   try JSON(data: catalog))
  }
  
  func testTruncatedPrefixesOfRealDocuments() throws {
    let data = try Data(contentsOf: self.dataURL("twitter.json"))
    let tweets = try XCTUnwrap(JSON(data: data).statuses?.arrayValue)
    let text = String(decoding: try tweets[0].data(formatting: [.sortedKeys]), as: UTF8.self)
    let bytes = Array(text.utf8)
    var previous: JSON? = nil
    for end in stride(from: 1, through: bytes.count, by: 7) {
      guard let prefix = String(bytes: bytes[0..<end], encoding: .utf8) else {
        continue
      }
      // Truncated documents are completed; numbers might be cut, but structure only grows
      if let value = try? JSON(lenient: prefix) {
        if let previous {
          XCTAssertTrue(self.hasStructure(of: previous, in: value), "at \(end)")
        }
        previous = value
      }
    }
    XCTAssertEqual(try self.lenient(text), tweets[0])
  }
  
  /// Does `value` contain all object members and array elements of `partial` (ignoring the
  /// contents of numbers and strings)?
  private func hasStructure(of partial: JSON, in value: JSON) -> Bool {
    switch (partial, value) {
      case (.array(let p), .array(let v)):
        return p.count <= v.count && zip(p, v).allSatisfy { self.hasStructure(of: $0, in: $1) }
      case (.object(let p), .object(let v)):
        return p.allSatisfy { key, member in
          v[key].map { self.hasStructure(of: member, in: $0) } ?? false
        }
      default:
        return partial.type.included(in: value.type) || value.type.included(in: partial.type) ||
               (partial.type == .integer || partial.type == .number)
    }
  }
}
