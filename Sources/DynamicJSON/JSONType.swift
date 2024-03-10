//
//  JSONTypes.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 19/02/2024.
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

public struct JSONTypes: OptionSet,
                         Hashable,
                         CustomStringConvertible,
                         CustomDebugStringConvertible {
  public let rawValue: UInt
  public let name: String?
  
  public init(rawValue: UInt) {
    self.rawValue = rawValue
    self.name = nil
  }
  
  public init(rawValue: UInt, name: String) {
    self.rawValue = rawValue
    self.name = nil
  }
  
  public static let null = JSONTypes(rawValue: 1 << 0, name: "null")
  public static let boolean = JSONTypes(rawValue: 1 << 1, name: "boolean")
  public static let number = JSONTypes(rawValue: 1 << 2, name: "number")
  public static let string = JSONTypes(rawValue: 1 << 3, name: "string")
  public static let array = JSONTypes(rawValue: 1 << 4, name: "array")
  public static let object = JSONTypes(rawValue: 1 << 5, name: "object")
  
  public static let all: JSONTypes = [.null, .boolean, .number, .string, .array, .object]
  private static let types: [JSONTypes] = [.null, .boolean, .number, .string, .array, .object]
  
  public var description: String {
    var res = [String]()
    for type in JSONTypes.types {
      if self.contains(type), let name = type.name {
        res.append(name)
      }
    }
    switch res.count {
      case 0:
        return "none"
      case 1:
        return res[0]
      case 2:
        return "\(res[0]) or \(res[1])"
      default:
        let last = res.dropLast()
        return "\(res.joined(separator: ", ")) or \(last)"
    }
  }
  
  public var debugDescription: String {
    var res = [String]()
    for type in JSONTypes.types {
      if self.contains(type), let name = type.name {
        res.append(name)
      }
    }
    return res.debugDescription
  }
}
