//
//  JSONReference.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 10/03/2024.
//  Copyright © 2024 Matthias Zenger. All rights reserved.
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
/// Implementations of the `JSONReference` protocol can be used to refer to
/// individual values within a JSON document. There are currently two implementations
/// coming with the DynamicJSON framework: `JSONPointer` (implementing RFC 6901) and
/// `JSONLocation` (implementing singular JSONPath queries as defined by RFC 9535)
///
public protocol JSONReference: CustomStringConvertible {
  
  /// Returns a new JSONReference with the given member selected.
  func select(member: String) -> Self
  
  /// Returns a new JSONReference with the given index selected.
  func select(index: Int) -> Self
  
  /// Retrieve value at which this reference is pointing from JSON document `value`.
  /// If the reference does not match any value, `nil` is returned.
  func get(from value: JSON) -> JSON?
  
  /// Replace value at which this reference is pointing with `json` within JSON
  /// document `value`. If the reference does not match any value, an error is thrown.
  func set(to json: JSON, in value: JSON) throws -> JSON
  
  /// Mutate value at which this reference is pointing within JSON document `value`
  /// with function `proc`. `proc` is provided a reference, enabling efficient,
  /// in-place mutations that do not trigger copying large parts of the JSON
  /// document.
  func mutate(_ json: inout JSON, with proc: (inout JSON) throws -> Void, insert: Bool) throws
}

extension JSONReference {
  /// Does this reference point to an existing value within `json`?
  public func exists(for json: JSON) -> Bool {
    return self.get(from: json) != nil
  }
}

///
/// Implementations of the `SegmentableJSONReference` protocol use a sequence of
/// segments to identify a value within a JSON document. Each segment needs to implement
/// the `JSONReferenceSegment` protocol.
///
public protocol SegmentableJSONReference: JSONReference {
  
  /// Segment type.
  associatedtype Segment: JSONReferenceSegment
  
  /// An array of segments representing the reference.
  var segments: [Segment] { get }
  
  /// Creates a new `SegmentableJSONReference` object of the same type to which the
  /// given segment is attached.
  func select(segment: Segment) -> Self
  
  /// Decomposes this `SegmentableJSONReference` object into the top segment selector and
  /// its parent `SegmentableJSONReference` object.
  var deselect: (Self, Segment)? { get }
}

///
/// Protocol implemented by segments of `SegmentableJSONReference` implementations.
///
public protocol JSONReferenceSegment {
  
  /// Returns an index and indicator whether the index is relative to the beginning or
  /// end of an array, if this is an index segment.
  var index: JSONReferenceSegmentIndex? { get }
  
  /// Returns a member name if this is a member segment.
  var member: String? { get }
}

///
/// An index together with an indicator whether the index is relative to the beginning or
/// end of an array.
///
public enum JSONReferenceSegmentIndex: Hashable, CustomStringConvertible {
  case fromStart(Int)
  case fromEnd(Int)
  
  public func value<T>(from array: [T]) throws -> T {
    switch self {
      case .fromStart(let offset):
        guard offset >= 0 && offset < array.count else {
          throw JSONReferenceError.indexOutOfBounds(offset, array.count)
        }
        return array[offset]
      case .fromEnd(let offset):
        guard offset > 0 && offset <= array.count else {
          throw JSONReferenceError.indexOutOfBounds(offset, array.count)
        }
        return array[array.count - offset]
    }
  }
  
  public var description: String {
    switch self {
      case .fromEnd(let index):
        return index == 0 ? "-" : "-\(index)"
      case .fromStart(let index):
        return "\(index)"
    }
  }
}

///
/// Collection of errors triggered by implementations of protocol `JSONReference`.
///
public enum JSONReferenceError: LocalizedError, CustomStringConvertible {
  case indexOutOfBounds(Int, Int)
  case erroneousIndexSelection(JSON, Int)
  case erroneousMemberSelection(JSON, String)
  
  public var description: String {
    switch self {
      case .indexOutOfBounds(let index, let count):
        return "index \(index) out of array bounds [0..\(count)["
      case .erroneousIndexSelection(let json, let index):
        return "cannot select value at index \(index) from \(json)"
      case .erroneousMemberSelection(let json, let member):
        return "cannot select member '\(member)' from \(json)"
    }
  }
  
  public var errorDescription: String? {
    return self.description
  }
  
  public var failureReason: String? {
    return "access error"
  }
}
