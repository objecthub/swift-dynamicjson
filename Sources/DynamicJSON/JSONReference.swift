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

public protocol JSONReference {
  func get(from value: JSON) -> JSON?
  func set(to json: JSON, in value: JSON) throws -> JSON
  func mutate(_ json: inout JSON, with proc: (inout JSON) throws -> Void) throws
}

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
