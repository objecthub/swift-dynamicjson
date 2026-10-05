//
//  JSONExtraction.swift
//  DynamicJSON
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

import Foundation

///
/// A deviation from the JSON standard that was accepted by lenient parsing, in order to make
/// sense of JSON produced by a large language model. See `JSON.init(lenient:repairTruncation:)`
/// and `JSON.extract(from:options:)`.
///
public enum JSONRepair: String, Hashable, Sendable, CaseIterable {
  
  /// The input contains comments (`// ...` or `/* ... */`).
  case comment
  
  /// A comma appears before a closing bracket or brace.
  case trailingComma
  
  /// A comma between two object members is missing.
  case missingComma
  
  /// A string is enclosed in single quotes.
  case singleQuotedString
  
  /// An object member name is not enclosed in quotes (as in `{name: "x"}`).
  case unquotedKey
  
  /// A literal such as `True`, `None`, `nil`, or `undefined` was used instead of `true`,
  /// `false`, or `null`.
  case nonStandardLiteral
  
  /// A number is not valid JSON, e.g. `+1`, `.5`, `5.`, `007`, or `0x1F`.
  case nonStandardNumber
  
  /// The input contains `NaN` or `Infinity`, which were replaced by `null`.
  case nonFiniteNumber
  
  /// A string contains unescaped control characters, such as line breaks.
  case rawControlCharacter
  
  /// A string contains an unknown escape sequence, which was replaced by the escaped
  /// character.
  case invalidEscape
  
  /// The input ends within a value. Open strings, arrays, and objects were closed, and
  /// incomplete members and elements were dropped.
  case truncated
}

///
/// Options for extracting JSON values from text.
///
public struct JSONExtractionOptions: Hashable, Sendable {
  
  /// Determines which parts of a text are searched for JSON values.
  public enum Scope: Hashable, Sendable {
    
    /// The whole text is searched.
    case anywhere
    
    /// Only the content of Markdown code blocks (enclosed in lines starting with three
    /// backticks or tildes) is searched.
    case fencedBlocks
  }
  
  /// The parts of the text that are searched. The default is `Scope.anywhere`.
  public var scope: Scope
  
  /// The types of values that are extracted. Values of other types are ignored. The default
  /// is `[.object, .array]`. Use `[.object]` to avoid false positives such as footnote
  /// markers (`[1]`) in prose.
  public var types: JSONType
  
  /// Are values that end prematurely accepted? If this is true (the default), open strings,
  /// arrays, and objects are closed and incomplete members are dropped. This is common if
  /// the output of a model was cut off because it exceeded its length limit.
  public var repairTruncation: Bool
  
  /// The maximum number of values extracted from a text, or `nil` for no limit.
  public var maxCount: Int?
  
  /// Creates extraction options.
  public init(scope: Scope = .anywhere,
              types: JSONType = [.object, .array],
              repairTruncation: Bool = true,
              maxCount: Int? = nil) {
    self.scope = scope
    self.types = types
    self.repairTruncation = repairTruncation
    self.maxCount = maxCount
  }
}

///
/// A JSON value that was found in a text.
///
public struct ExtractedJSON: Hashable, Sendable {
  
  /// Where a value was found.
  public enum Source: Hashable, Sendable {
    
    /// The value is part of the running text.
    case text
    
    /// The value is (part of) the content of a Markdown code block with the given language
    /// (the first word after the opening fence), if there is one.
    case fencedBlock(language: String?)
  }
  
  /// The extracted value.
  public let value: JSON
  
  /// The range of the text that holds the value in its original form.
  public let range: Range<String.Index>
  
  /// Where the value was found.
  public let source: Source
  
  /// The deviations from JSON that were accepted for extracting the value. If the set is
  /// empty, the source text of the value is valid JSON.
  public let repairs: Set<JSONRepair>
  
  /// Is the source text of the value valid JSON, i.e. no repairs were needed?
  public var isStrict: Bool {
    return self.repairs.isEmpty
  }
  
  /// Creates an extracted value.
  public init(value: JSON,
              range: Range<String.Index>,
              source: Source,
              repairs: Set<JSONRepair>) {
    self.value = value
    self.range = range
    self.source = source
    self.repairs = repairs
  }
}

extension JSON {
  
  ///
  /// Errors raised when parsing JSON leniently. Each case carries the offset in bytes (of the
  /// UTF-8 encoding of the text) at which the problem was found.
  ///
  public enum LenientError: LocalizedError, CustomStringConvertible, Equatable, Sendable {
    case unexpectedByte(UInt8, offset: Int)
    case unexpectedEnd(offset: Int)
    case invalidNumber(offset: Int)
    case trailingContent(offset: Int)
    case tooDeeplyNested(offset: Int)
    
    public var description: String {
      switch self {
        case .unexpectedByte(let byte, let offset):
          return "unexpected byte 0x\(String(byte, radix: 16)) at offset \(offset)"
        case .unexpectedEnd(let offset):
          return "unexpected end of input at offset \(offset)"
        case .invalidNumber(let offset):
          return "invalid number at offset \(offset)"
        case .trailingContent(let offset):
          return "unexpected content after the value at offset \(offset)"
        case .tooDeeplyNested(let offset):
          return "value nested too deeply at offset \(offset)"
      }
    }
    
    public var errorDescription: String? {
      return self.description
    }
    
    public var failureReason: String? {
      return "lenient parsing error"
    }
  }
}

///
/// The implementation of lenient parsing and of the extraction of values from text.
///
internal struct JSONExtractor {
  
  /// A Markdown code block.
  private struct Fence {
    let start: Int
    let contentStart: Int
    let contentEnd: Int
    let end: Int
    let language: String?
  }
  
  private let text: String
  private let bytes: [UInt8]
  private let options: JSONExtractionOptions
  
  init(text: String, options: JSONExtractionOptions) {
    self.text = text
    self.bytes = Array(text.utf8)
    self.options = options
  }
  
  // MARK: - Parsing one value
  
  /// Parses a text that consists of exactly one value, optionally enclosed in a code block.
  static func parse(_ text: String, repairTruncation: Bool) throws -> (JSON, Set<JSONRepair>) {
    let extractor = JSONExtractor(text: text,
                                  options: JSONExtractionOptions(repairTruncation: repairTruncation))
    var start = 0
    var end = extractor.bytes.count
    // Look through a code block surrounding the value
    let fences = extractor.fences()
    if let fence = fences.first,
       extractor.bytes[0..<fence.start].allSatisfy(isJSONWhitespace),
       extractor.bytes[fence.end..<end].allSatisfy(isJSONWhitespace) {
      start = fence.contentStart
      end = fence.contentEnd
    }
    var parser = JSONLenientParser(bytes: extractor.bytes,
                                   start: start,
                                   end: end,
                                   repairTruncation: repairTruncation)
    guard let value = try parser.parseValue() else {
      throw JSON.LenientError.unexpectedEnd(offset: parser.pos)
    }
    try parser.skipTrivia()
    guard parser.atEnd else {
      throw JSON.LenientError.trailingContent(offset: parser.pos)
    }
    return (value, parser.repairs)
  }
  
  // MARK: - Extraction
  
  /// Finds all values in the text, in the order in which they appear.
  func extract() -> [ExtractedJSON] {
    var results: [ExtractedJSON] = []
    let fences = self.fences()
    var pos = 0
    var next = 0
    while pos < self.bytes.count && !self.isFull(results) {
      if next < fences.count && pos >= fences[next].start {
        let fence = fences[next]
        next += 1
        self.extract(fence: fence, into: &results)
        pos = fence.end
        continue
      }
      let limit = next < fences.count ? fences[next].start : self.bytes.count
      if self.options.scope == .fencedBlocks {
        pos = limit
        continue
      }
      self.scan(from: pos, to: limit, source: .text, into: &results)
      pos = limit
    }
    return results
  }
  
  private func isFull(_ results: [ExtractedJSON]) -> Bool {
    guard let max = self.options.maxCount else {
      return false
    }
    return results.count >= max
  }
  
  /// Extracts the values of a code block.
  private func extract(fence: Fence, into results: inout [ExtractedJSON]) {
    let source = ExtractedJSON.Source.fencedBlock(language: fence.language)
    // The content of a code block is most often exactly one value
    var parser = JSONLenientParser(bytes: self.bytes,
                                   start: fence.contentStart,
                                   end: fence.contentEnd,
                                   repairTruncation: self.options.repairTruncation)
    if let first = try? parser.parseValue(), (try? parser.skipTrivia()) != nil, parser.atEnd {
      if first.type.included(in: self.options.types) {
        self.append(first,
                    parser: parser,
                    from: self.firstNonTrivia(fence.contentStart, fence.contentEnd),
                    source: source,
                    into: &results)
      }
      return
    }
    self.scan(from: fence.contentStart, to: fence.contentEnd, source: source, into: &results)
  }
  
  /// Searches the bytes in a range for objects and arrays.
  private func scan(from start: Int,
                    to end: Int,
                    source: ExtractedJSON.Source,
                    into results: inout [ExtractedJSON]) {
    var pos = start
    while pos < end && !self.isFull(results) {
      let byte = self.bytes[pos]
      if byte == UInt8(ascii: "{") || byte == UInt8(ascii: "[") {
        var parser = JSONLenientParser(bytes: self.bytes,
                                       start: pos,
                                       end: end,
                                       repairTruncation: self.options.repairTruncation)
        if let value = try? parser.parseValue(),
           value.type.included(in: self.options.types) {
          self.append(value, parser: parser, from: pos, source: source, into: &results)
          pos = parser.pos
          continue
        }
      }
      pos += 1
    }
  }
  
  private func append(_ value: JSON,
                      parser: JSONLenientParser,
                      from start: Int,
                      source: ExtractedJSON.Source,
                      into results: inout [ExtractedJSON]) {
    let utf8 = self.text.utf8
    let lower = utf8.index(utf8.startIndex, offsetBy: start)
    let upper = utf8.index(utf8.startIndex, offsetBy: parser.pos)
    results.append(ExtractedJSON(value: value,
                                 range: lower..<upper,
                                 source: source,
                                 repairs: parser.repairs))
  }
  
  private func firstNonTrivia(_ start: Int, _ end: Int) -> Int {
    var pos = start
    while pos < end && isJSONWhitespace(self.bytes[pos]) {
      pos += 1
    }
    return pos
  }
  
  // MARK: - Code blocks
  
  /// Returns the Markdown code blocks of the text.
  private func fences() -> [Fence] {
    var res: [Fence] = []
    var lineStart = 0
    var open: (start: Int, contentStart: Int, marker: UInt8, length: Int, language: String?)? = nil
    while lineStart < self.bytes.count {
      var lineEnd = lineStart
      while lineEnd < self.bytes.count && self.bytes[lineEnd] != 0x0A {
        lineEnd += 1
      }
      let next = min(lineEnd + 1, self.bytes.count)
      var i = lineStart
      while i < lineEnd && i < lineStart + 3 && self.bytes[i] == 0x20 {
        i += 1
      }
      var length = 0
      let marker = i < lineEnd ? self.bytes[i] : 0
      if marker == UInt8(ascii: "`") || marker == UInt8(ascii: "~") {
        while i + length < lineEnd && self.bytes[i + length] == marker {
          length += 1
        }
      }
      if let current = open {
        let rest = self.bytes[(i + length)..<lineEnd]
        if marker == current.marker && length >= current.length &&
           rest.allSatisfy({ isJSONWhitespace($0) }) {
          res.append(Fence(start: current.start,
                           contentStart: current.contentStart,
                           contentEnd: lineStart,
                           end: next,
                           language: current.language))
          open = nil
        }
      } else if length >= 3 {
        let info = self.bytes[(i + length)..<lineEnd]
        // The info string of a fence with backticks must not contain backticks
        if marker != UInt8(ascii: "`") || !info.contains(UInt8(ascii: "`")) {
          let word = String(decoding: info, as: UTF8.self)
                       .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\r" })
                       .first
          open = (lineStart, next, marker, length, word.map { String($0) })
        }
      }
      lineStart = next
    }
    if let current = open {
      // A code block that is not closed extends to the end of the text
      res.append(Fence(start: current.start,
                       contentStart: current.contentStart,
                       contentEnd: self.bytes.count,
                       end: self.bytes.count,
                       language: current.language))
    }
    return res
  }
}

extension JSON {
  
  /// Creates a JSON value by parsing the given text leniently, i.e. while accepting
  /// the deviations from JSON listed in `JSONRepair`, which are typical for output of
  /// large language models. The text has to consist of exactly one value, optionally
  /// surrounded by whitespace or by a Markdown code block. Use `extract(from:options:)` for
  /// finding values in running text. Throws a `JSON.LenientError` if there is no value.
  ///
  /// If `repairTruncation` is true (the default), a value that ends prematurely is
  /// completed: open strings, arrays, and objects are closed, and incomplete members and
  /// elements are dropped.
  public init(lenient text: String, repairTruncation: Bool = true) throws {
    self = try JSONExtractor.parse(text, repairTruncation: repairTruncation).0
  }
  
  /// Returns the objects and arrays that can be found in `text`, which is typically the
  /// response of a large language model. The text is searched for Markdown code blocks and
  /// for JSON objects and arrays in running text. The values are parsed leniently; the
  /// `repairs` of each result tell which deviations from JSON were accepted. Results
  /// are returned in the order in which they appear in the text, and each result has the
  /// range of the text it was found in.
  ///
  ///     let answer = """
  ///       Sure! Here is the data you asked for:
  ///       ```json
  ///       { "name": "Ada", "languages": ["en", "fr",], }
  ///       ```
  ///       Let me know if you need anything else.
  ///       """
  ///     JSON.extract(from: answer).first?.value   // {"name": "Ada", "languages": ["en", "fr"]}
  public static func extract(from text: String,
                             options: JSONExtractionOptions = JSONExtractionOptions())
                                                                          -> [ExtractedJSON] {
    return JSONExtractor(text: text, options: options).extract()
  }
  
  /// Returns the first value that can be found in `text`; see `extract(from:options:)`.
  public static func extractFirst(from text: String,
                                  options: JSONExtractionOptions = JSONExtractionOptions())
                                                                          -> ExtractedJSON? {
    var options = options
    options.maxCount = 1
    return JSONExtractor(text: text, options: options).extract().first
  }
}
