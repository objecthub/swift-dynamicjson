//
//  LocatedJSON.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 17/03/2024.
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
/// A JSON value together with its corresponding location within another JSON value.
/// `JSONLocation` is used as a location identifier; i.e. this struct is mostly of
/// interest for JSONPath-based use cases.
///
public struct LocatedJSON: Hashable, CustomStringConvertible {
  public let value: JSON
  public let location: JSONLocation
  
  /// Returns a new `LocatedJSON` value representing the full document.
  public static func root(_ value: JSON) -> LocatedJSON {
    return LocatedJSON(root: value)
  }
  
  /// Initializes a new `LocatedJSON` value representing the full document.
  public init(root: JSON) {
    self.init(root, .root)
  }
  
  /// Initializes a new `LocatedJSON` value given a JSON value and its location.
  public init(_ value: JSON, _ location: JSONLocation) {
    self.value = value
    self.location = location
  }
  
  /// Returns a new `LocatedJSON` for the value at index `i` of the array
  /// represented by this `LocatedJSON` struct.
  public func index(_ i: Int) -> LocatedJSON? {
    guard case .array(let arr) = self.value else {
      return nil
    }
    let index = i < 0 ? arr.count + i : i
    guard arr.indices.contains(index) else {
      return nil
    }
    return LocatedJSON(arr[index], .index(self.location, index))
  }
  
  /// Returns a new `LocatedJSON` for the member value `member` of the object
  /// represented by this `LocatedJSON` struct.
  public func member(_ member: String) -> LocatedJSON? {
    guard case .object(let dict) = self.value, let val = dict[member] else {
      return nil
    }
    return LocatedJSON(val, .member(self.location, member))
  }
  
  /// Applies the given function to all descendents (i.e. direct and indirect children)
  /// of this `LocatedJSON` value.
  public func forEachDescendant(_ proc: (LocatedJSON) throws -> Void) rethrows {
    try proc(self)
    switch self.value {
      case .array(let arr):
        for i in arr.indices {
          try LocatedJSON(arr[i], .index(location, i)).forEachDescendant(proc)
        }
      case .object(let dict):
        for (key, value) in dict {
          try LocatedJSON(value, .member(location, key)).forEachDescendant(proc)
        }
      default:
        break
    }
  }
  
  /// Returns a textual description of this `LocatedJSON` value.
  public var description: String {
    return "\(self.location) => \(self.value)"
  }
}
