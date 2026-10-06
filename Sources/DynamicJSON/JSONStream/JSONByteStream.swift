//
//  JSONByteStream.swift
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

///
/// An asynchronous sequence of chunks of data, which together form a stream of JSON values
/// in one of the formats of `JSON.StreamFormat`. Use `JSON.stream(_:format:options:)` to create
/// a `JSONByteStream` from an asynchronous sequence of JSON values. There is one chunk for each
/// value, followed by a chunk with the closing bytes of the stream, if there are any. The chunks
/// can be sent to a client as the body of a streaming HTTP response, or be written to a file.
/// The sequence throws a `JSON.StreamWriteError` if a value cannot be encoded; errors of the
/// base sequence are passed on.
///
public struct JSONByteStream<Base: AsyncSequence>: AsyncSequence {
  public typealias Element = Data
  
  private let base: Base
  private let format: JSON.StreamFormat
  private let options: JSON.StreamWriteOptions
  private let write: (inout JSONStreamWriter, Base.Element) throws -> Data
  
  internal init(base: Base,
                format: JSON.StreamFormat,
                options: JSON.StreamWriteOptions,
                write: @escaping (inout JSONStreamWriter, Base.Element) throws -> Data) {
    self.base = base
    self.format = format
    self.options = options
    self.write = write
  }
  
  public func makeAsyncIterator() -> AsyncIterator {
    return AsyncIterator(base: self.base.makeAsyncIterator(),
                         format: self.format,
                         options: self.options,
                         write: self.write)
  }
  
  public struct AsyncIterator: AsyncIteratorProtocol {
    private var base: Base.AsyncIterator
    private let format: JSON.StreamFormat
    private let options: JSON.StreamWriteOptions
    private let write: (inout JSONStreamWriter, Base.Element) throws -> Data
    private var writer: JSONStreamWriter? = nil
    private var finished = false
    
    internal init(base: Base.AsyncIterator,
                  format: JSON.StreamFormat,
                  options: JSON.StreamWriteOptions,
                  write: @escaping (inout JSONStreamWriter, Base.Element) throws -> Data) {
      self.base = base
      self.format = format
      self.options = options
      self.write = write
    }
    
    public mutating func next() async throws -> Data? {
      if self.finished {
        return nil
      }
      var writer = try self.writer ?? JSONStreamWriter(format: self.format, options: self.options)
      defer {
        self.writer = writer
      }
      do {
        if let element = try await self.base.next() {
          return try self.write(&writer, element)
        }
      } catch {
        self.finished = true
        throw error
      }
      self.finished = true
      let closing = try writer.finish()
      return closing.isEmpty ? nil : closing
    }
  }
}
