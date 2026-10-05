//
//  JSONValueStream.swift
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
/// An asynchronous sequence of the JSON values found in an asynchronous sequence of bytes.
/// Use `JSON.values(from:format:options:)` to create a `JSONValueStream`. Iterating over
/// the stream throws a `JSON.StreamError` if the input is malformed (unless the error policy
/// is `JSON.StreamErrorPolicy.skipInvalid`). The stream ends after an error was thrown.
///
public struct JSONValueStream<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
  public typealias Element = JSON
  
  private let base: Base
  private let format: JSON.StreamFormat
  private let options: JSON.StreamOptions
  
  internal init(base: Base, format: JSON.StreamFormat, options: JSON.StreamOptions) {
    self.base = base
    self.format = format
    self.options = options
  }
  
  public func makeAsyncIterator() -> AsyncIterator {
    return AsyncIterator(base: self.base.makeAsyncIterator(),
                         core: JSONStreamCore(format: self.format, options: self.options),
                         policy: self.options.errors)
  }
  
  public struct AsyncIterator: AsyncIteratorProtocol {
    private var base: Base.AsyncIterator
    private var core: JSONStreamCore
    private let policy: JSON.StreamErrorPolicy
    
    internal init(base: Base.AsyncIterator,
                  core: JSONStreamCore,
                  policy: JSON.StreamErrorPolicy) {
      self.base = base
      self.core = core
      self.policy = policy
    }
    
    public mutating func next() async throws -> JSON? {
      while true {
        switch self.core.poll() {
          case .success(let json):
            return json
          case .failure(let error):
            if self.policy == .fail || error.isFatal {
              self.core.halt()
              throw error
            }
            continue
          case nil:
            break
        }
        if self.core.isDone {
          return nil
        }
        if let byte = try await self.base.next() {
          self.core.push(byte)
        } else {
          self.core.finish()
        }
      }
    }
  }
}

extension JSONValueStream: Sendable where Base: Sendable {}

///
/// An asynchronous sequence of results, one for each JSON value found in an asynchronous
/// sequence of bytes. Use `JSON.results(from:format:options:)` to create a `JSONResultStream`.
/// Malformed values do not throw; they are returned as failures, which allows a client to
/// decide whether and how to continue. The stream ends after a fatal error (see
/// `JSON.StreamError.isFatal`) was returned.
///
public struct JSONResultStream<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
  public typealias Element = Result<JSON, JSON.StreamError>
  
  private let base: Base
  private let format: JSON.StreamFormat
  private let options: JSON.StreamOptions
  
  internal init(base: Base, format: JSON.StreamFormat, options: JSON.StreamOptions) {
    self.base = base
    self.format = format
    self.options = options
  }
  
  public func makeAsyncIterator() -> AsyncIterator {
    return AsyncIterator(base: self.base.makeAsyncIterator(),
                         core: JSONStreamCore(format: self.format, options: self.options))
  }
  
  public struct AsyncIterator: AsyncIteratorProtocol {
    private var base: Base.AsyncIterator
    private var core: JSONStreamCore
    
    internal init(base: Base.AsyncIterator, core: JSONStreamCore) {
      self.base = base
      self.core = core
    }
    
    public mutating func next() async throws -> Result<JSON, JSON.StreamError>? {
      while true {
        if let result = self.core.poll() {
          return result
        }
        if self.core.isDone {
          return nil
        }
        // Errors of the underlying sequence are thrown, they are not stream errors.
        if let byte = try await self.base.next() {
          self.core.push(byte)
        } else {
          self.core.finish()
        }
      }
    }
  }
}

extension JSONResultStream: Sendable where Base: Sendable {}

///
/// A lazy sequence of results, one for each JSON value found in a sequence of bytes. Use
/// `JSON.results(from:format:options:)` to create a `JSONResultSequence`.
///
public struct JSONResultSequence<Base: Sequence>: Sequence where Base.Element == UInt8 {
  public typealias Element = Result<JSON, JSON.StreamError>
  
  private let base: Base
  private let format: JSON.StreamFormat
  private let options: JSON.StreamOptions
  
  internal init(base: Base, format: JSON.StreamFormat, options: JSON.StreamOptions) {
    self.base = base
    self.format = format
    self.options = options
  }
  
  public func makeIterator() -> Iterator {
    return Iterator(base: self.base.makeIterator(),
                    core: JSONStreamCore(format: self.format, options: self.options))
  }
  
  public struct Iterator: IteratorProtocol {
    private var base: Base.Iterator
    private var core: JSONStreamCore
    
    internal init(base: Base.Iterator, core: JSONStreamCore) {
      self.base = base
      self.core = core
    }
    
    public mutating func next() -> Result<JSON, JSON.StreamError>? {
      while true {
        if let result = self.core.poll() {
          return result
        }
        if self.core.isDone {
          return nil
        }
        if let byte = self.base.next() {
          self.core.push(byte)
        } else {
          self.core.finish()
        }
      }
    }
  }
}
