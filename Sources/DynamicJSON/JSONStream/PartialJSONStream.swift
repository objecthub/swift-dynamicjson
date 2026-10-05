//
//  PartialJSONStream.swift
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
/// A snapshot of a JSON value that is received in fragments; see `JSONPartialParser`.
///
public struct PartialJSON: Hashable, Sendable {
  
  /// The best approximation of the JSON value received so far.
  public let value: JSON
  
  /// Is `value` the complete JSON value?
  public let isComplete: Bool
  
  /// Creates a snapshot.
  public init(value: JSON, isComplete: Bool) {
    self.value = value
    self.isComplete = isComplete
  }
  
  /// Returns a JSON patch that transforms the value of the `previous` snapshot into the
  /// value of this snapshot. It allows clients to apply only the changes between two
  /// snapshots, e.g. to a user interface. If there is no previous snapshot, the patch
  /// transforms `null` into the value of this snapshot.
  public func patch(from previous: PartialJSON?) -> JSONPatch {
    return (previous?.value ?? .null).patch(to: self.value)
  }
}

///
/// An asynchronous sequence of successive snapshots of a JSON value that arrives in
/// fragments, such as the structured output of a large language model. Use
/// `JSON.partialValues(from:)` to create a `PartialJSONStream`. A new snapshot is returned
/// whenever the approximation of the value changes. The last snapshot is the complete
/// value. If the stream of fragments ends before the value is complete, or if the
/// fragments are not valid JSON, the sequence throws a `JSON.StreamError`.
///
public struct PartialJSONStream<Base: AsyncSequence>: AsyncSequence {
  public typealias Element = PartialJSON
  
  private let base: Base
  private let feed: (inout JSONPartialParser, Base.Element) throws -> Void
  
  internal init(base: Base,
                feed: @escaping (inout JSONPartialParser, Base.Element) throws -> Void) {
    self.base = base
    self.feed = feed
  }
  
  public func makeAsyncIterator() -> AsyncIterator {
    return AsyncIterator(base: self.base.makeAsyncIterator(), feed: self.feed)
  }
  
  public struct AsyncIterator: AsyncIteratorProtocol {
    private var base: Base.AsyncIterator
    private let feed: (inout JSONPartialParser, Base.Element) throws -> Void
    private var parser = JSONPartialParser()
    private var last: PartialJSON? = nil
    private var finished = false
    
    internal init(base: Base.AsyncIterator,
                  feed: @escaping (inout JSONPartialParser,
                                   Base.Element) throws -> Void) {
      self.base = base
      self.feed = feed
    }
    
    public mutating func next() async throws -> PartialJSON? {
      while !self.finished {
        let next: PartialJSON
        if let fragment = try await self.base.next() {
          try self.feed(&self.parser, fragment)
          guard let value = try self.parser.snapshot() else {
            continue
          }
          next = PartialJSON(value: value, isComplete: self.parser.isComplete)
        } else {
          self.finished = true
          next = PartialJSON(value: try self.parser.finish(), isComplete: true)
        }
        if next != self.last {
          self.last = next
          return next
        }
      }
      return nil
    }
  }
}

///
/// An asynchronous sequence of the strings found at a given location in a sequence of JSON
/// values. Use `JSON.fragments(from:at:)` to create a `JSONFragmentStream`.
///
public struct JSONFragmentStream<Base: AsyncSequence>: AsyncSequence where Base.Element == JSON {
  public typealias Element = String
  
  private let base: Base
  private let pointer: JSONPointer
  
  internal init(base: Base, pointer: JSONPointer) {
    self.base = base
    self.pointer = pointer
  }
  
  public func makeAsyncIterator() -> AsyncIterator {
    return AsyncIterator(base: self.base.makeAsyncIterator(), pointer: self.pointer)
  }
  
  public struct AsyncIterator: AsyncIteratorProtocol {
    private var base: Base.AsyncIterator
    private let pointer: JSONPointer
    
    internal init(base: Base.AsyncIterator, pointer: JSONPointer) {
      self.base = base
      self.pointer = pointer
    }
    
    public mutating func next() async throws -> String? {
      while let json = try await self.base.next() {
        if let string = self.pointer.get(from: json)?.stringValue {
          return string
        }
      }
      return nil
    }
  }
}

extension JSON {
  
  /// Returns an asynchronous sequence of snapshots of a single JSON value that arrives in
  /// fragments of text, e.g. the arguments of a tool call streamed by a large language model.
  /// Each element is the best approximation of the value received so far; see
  /// `JSONPartialParser` for the rules. The last element is the complete value.
  ///
  ///     for try await partial in JSON.partialValues(from: argumentFragments) {
  ///       print(partial.value, partial.isComplete)
  ///     }
  public static func partialValues<S: AsyncSequence>(
      from fragments: S) -> PartialJSONStream<S> where S.Element: StringProtocol {
    return PartialJSONStream(base: fragments) { parser, fragment in
      try parser.append(contentsOf: fragment.utf8)
    }
  }
  
  /// Returns an asynchronous sequence of snapshots of a single JSON value that arrives in
  /// chunks of data; see `partialValues(from:)` for fragments of text.
  public static func partialValues<S: AsyncSequence>(
      from chunks: S) -> PartialJSONStream<S> where S.Element: DataProtocol {
    return PartialJSONStream(base: chunks) { parser, chunk in
      try parser.append(contentsOf: Data(chunk))
    }
  }
  
  /// Returns an asynchronous sequence of snapshots of a single JSON value that arrives as
  /// a sequence of UTF-8 encoded bytes; see `partialValues(from:)` for fragments of text.
  public static func partialValues<S: AsyncSequence>(
      from bytes: S) -> PartialJSONStream<S> where S.Element == UInt8 {
    return PartialJSONStream(base: bytes) { parser, byte in
      try parser.append(contentsOf: CollectionOfOne(byte))
    }
  }
  
  /// Returns an asynchronous sequence of the strings found at `pointer` in the JSON values
  /// of `values`. Values without a string at this location are skipped. Streaming APIs
  /// of large language models deliver their output in small JSON events; this function
  /// extracts the text fragments from these events, e.g. `/choices/0/delta/content`
  /// (OpenAI) or `/delta/partial_json` (Anthropic tool input), for example to feed them
  /// into `partialValues(from:)`:
  ///
  ///     let events = JSON.values(from: response.bytes, format: .serverSentEvents)
  ///     let fragments = JSON.fragments(from: events, at: try JSONPointer("/delta/partial_json"))
  ///     for try await partial in JSON.partialValues(from: fragments) { ... }
  public static func fragments<S: AsyncSequence>(
      from values: S,
      at pointer: JSONPointer) -> JSONFragmentStream<S> where S.Element == JSON {
    return JSONFragmentStream(base: values, pointer: pointer)
  }
}
