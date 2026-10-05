//
//  JSON+Streaming.swift
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
/// Reading sequences of JSON values.
///
/// Many sources deliver not one JSON document, but a sequence of JSON values: log files, web
/// service responses, or the output of other processes. The functions below provide a single
/// entry point for all common ways of transporting such sequences; see
/// `JSON.StreamFormat` for the supported formats.
///
/// Values can be read from asynchronous byte sequences (such as `URL.resourceBytes`,
/// `FileHandle.bytes`, or `URLSession.bytes(from:)`), as well as from in-memory data.
///
extension JSON {
  
  // MARK: - Asynchronous streams
  
  /// Returns an asynchronous sequence of the JSON values found in `bytes`, assuming `format`.
  /// A `for try await` loop over the result throws a `JSON.StreamError` when it reaches a
  /// malformed value, unless `options.errors` is `JSON.StreamErrorPolicy.skipInvalid`.
  ///
  ///     for try await value in JSON.values(from: url.resourceBytes, format: .lines) {
  ///       print(value)
  ///     }
  public static func values<S: AsyncSequence>(
      from bytes: S,
      format: StreamFormat = .automatic,
      options: StreamOptions = StreamOptions()) -> JSONValueStream<S> where S.Element == UInt8 {
    return JSONValueStream(base: bytes, format: format, options: options)
  }
  
  /// Returns an asynchronous sequence of results for the JSON values found in `bytes`,
  /// assuming `format`. Malformed values are returned as failures instead of being thrown,
  /// which allows clients to inspect errors and to continue reading.
  public static func results<S: AsyncSequence>(
      from bytes: S,
      format: StreamFormat = .automatic,
      options: StreamOptions = StreamOptions()) -> JSONResultStream<S> where S.Element == UInt8 {
    return JSONResultStream(base: bytes, format: format, options: options)
  }
  
#if os(iOS) || os(watchOS) || os(tvOS) || os(macOS)
  /// Returns an asynchronous sequence of the JSON values found in the resource at `url`,
  /// assuming `format`.
  public static func values(
      contentsOf url: URL,
      format: StreamFormat = .automatic,
      options: StreamOptions = StreamOptions()) -> JSONValueStream<URL.AsyncBytes> {
    return JSONValueStream(base: url.resourceBytes, format: format, options: options)
  }
#endif
  
  // MARK: - Synchronous access
  
  /// Returns a lazy sequence of results for the JSON values found in `bytes` (e.g. a `Data`
  /// object), assuming `format`.
  public static func results<S: Sequence>(
      from bytes: S,
      format: StreamFormat = .automatic,
      options: StreamOptions = StreamOptions()) -> JSONResultSequence<S> where S.Element == UInt8 {
    return JSONResultSequence(base: bytes, format: format, options: options)
  }
  
  /// Returns an array with all JSON values found in `bytes` (e.g. a `Data` object), assuming
  /// `format`. Throws a `JSON.StreamError` for malformed input, unless `options.errors` is
  /// `JSON.StreamErrorPolicy.skipInvalid`.
  public static func values<S: Sequence>(
      from bytes: S,
      format: StreamFormat = .automatic,
      options: StreamOptions = StreamOptions()) throws -> [JSON] where S.Element == UInt8 {
    var res: [JSON] = []
    for result in JSON.results(from: bytes, format: format, options: options) {
      switch result {
        case .success(let json):
          res.append(json)
        case .failure(let error):
          if options.errors == .fail || error.isFatal {
            throw error
          }
      }
    }
    return res
  }
  
  /// Returns an array with all JSON values found in the given string, assuming `format`.
  public static func values(
      from string: String,
      format: StreamFormat = .automatic,
      options: StreamOptions = StreamOptions()) throws -> [JSON] {
    return try JSON.values(from: string.utf8, format: format, options: options)
  }
}
