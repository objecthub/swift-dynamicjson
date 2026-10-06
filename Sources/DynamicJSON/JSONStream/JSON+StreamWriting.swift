//
//  JSON+StreamWriting.swift
//  DynamicJSON
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

import Foundation

extension JSON {
  
  // MARK: - Asynchronous streams
  
  /// Returns an asynchronous sequence of chunks of data that form a stream of the JSON values
  /// of `values` in the given format. The result is typically used as the body of a streaming
  /// HTTP response or written to a file. Only formats that are not `StreamFormat.automatic` can
  /// be used; the sequence throws a `JSON.StreamWriteError` otherwise.
  ///
  ///     for try await chunk in JSON.stream(values, format: .lines) {
  ///       try handle.write(contentsOf: chunk)
  ///     }
  public static func stream<S: AsyncSequence>(
      _ values: S,
      format: StreamFormat,
      options: StreamWriteOptions = StreamWriteOptions()) -> JSONByteStream<S>
                                                                      where S.Element == JSON {
    return JSONByteStream(base: values, format: format, options: options) { writer, value in
      try writer.write(value)
    }
  }
  
  /// Returns an asynchronous sequence of chunks of data that form a stream of the `Encodable`
  /// values of `values` in the given format; see `stream(_:format:options:)`.
  public static func stream<S: AsyncSequence>(
      encoding values: S,
      format: StreamFormat,
      options: StreamWriteOptions = StreamWriteOptions()) -> JSONByteStream<S>
                                                                where S.Element: Encodable {
    return JSONByteStream(base: values, format: format, options: options) { writer, value in
      try writer.write(value)
    }
  }
  
  /// Returns an asynchronous sequence of chunks of data that form a stream of server-sent
  /// events (`text/event-stream`).
  public static func stream<S: AsyncSequence>(
      events: S,
      options: StreamWriteOptions = StreamWriteOptions()) -> JSONByteStream<S>
                                                              where S.Element == ServerSentEvent {
    return JSONByteStream(base: events,
                          format: .serverSentEvents,
                          options: options) { writer, event in
      try writer.write(event)
    }
  }
  
  // MARK: - Data
  
  /// Returns the stream of the JSON values of `values` in the given format as a `Data`
  /// object. Values written in this way can be read again with
  /// `JSON.values(from:format:options:)`.
  public static func stream<S: Sequence>(
      _ values: S,
      format: StreamFormat,
      options: StreamWriteOptions = StreamWriteOptions()) throws -> Data where S.Element == JSON {
    var writer = try JSONStreamWriter(format: format, options: options)
    var data = Data()
    for value in values {
      data.append(try writer.write(value))
    }
    data.append(try writer.finish())
    return data
  }
  
  /// Returns the stream of the `Encodable` values of `values` in the given format as a `Data`
  /// object.
  public static func stream<S: Sequence>(
      encoding values: S,
      format: StreamFormat,
      options: StreamWriteOptions = StreamWriteOptions()) throws -> Data
                                                                where S.Element: Encodable {
    var writer = try JSONStreamWriter(format: format, options: options)
    var data = Data()
    for value in values {
      data.append(try writer.write(value))
    }
    data.append(try writer.finish())
    return data
  }
  
  // MARK: - Files
  
  /// Writes the JSON values of `values` in the given format to a file. An existing file is
  /// replaced.
  public static func write<S: Sequence>(
      _ values: S,
      to url: URL,
      format: StreamFormat,
      options: StreamWriteOptions = StreamWriteOptions()) throws where S.Element == JSON {
    var writer = try JSONStreamWriter(format: format, options: options)
    let handle = try self.createFile(at: url)
    defer {
      try? handle.close()
    }
    for value in values {
      try handle.write(contentsOf: try writer.write(value))
    }
    try handle.write(contentsOf: try writer.finish())
  }
  
  /// Writes the JSON values of `values` in the given format to a file. The values are written
  /// as soon as they become available. An existing file is replaced.
  public static func write<S: AsyncSequence>(
      _ values: S,
      to url: URL,
      format: StreamFormat,
      options: StreamWriteOptions = StreamWriteOptions()) async throws where S.Element == JSON {
    let handle = try self.createFile(at: url)
    defer {
      try? handle.close()
    }
    for try await chunk in JSON.stream(values, format: format, options: options) {
      try handle.write(contentsOf: chunk)
    }
  }
  
  private static func createFile(at url: URL) throws -> FileHandle {
    guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
      throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
    }
    return try FileHandle(forWritingTo: url)
  }
}
