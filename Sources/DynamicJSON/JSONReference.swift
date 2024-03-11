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
public protocol JSONReference {
  
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
  func mutate(_ json: inout JSON, with proc: (inout JSON) throws -> Void) throws
}

///
/// Collection of errors triggered by implementations of protocol `JSONReference`.
///
public enum JSONReferenceError: LocalizedError, CustomStringConvertible {
  case erroneousIndexSelection(JSON, Int)
  case erroneousMemberSelection(JSON, String)
  
  public var description: String {
    switch self {
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
