//
//  JSONPathEnvironment.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 18/02/2024.
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

open class JSONPathEnvironment {
  public var variables: [String : JSONPathEvaluator.Value] = [:]
  public var functions: [String : JSONPathEvaluator.Function] = [:]
  
  init(variables: [String : JSONPathEvaluator.Value] = [:],
       functions: [String : JSONPathEvaluator.Function] = [:]) {
    self.variables = variables
    self.functions = functions
    self.initialize()
  }
  
  open func initialize() {
    self.variables["pi"] = .json(.float(.pi))
    self.functions["length"] = JSONPathEvaluator.Function(
      argtypes: [.jsonType],
      restype: .jsonType,
      impl: { root, current, args throws in
        switch args[0] {
          case .json(.array(let arr)):
            return .json(.integer(Int64(arr.count)))
          case .json(.string(let str)):
            return .json(.integer(Int64(str.count)))
          case .json(.object(let dict)):
            return .json(.integer(Int64(dict.count)))
          default:
            return .json(nil)
        }
      })
    self.functions["count"] = JSONPathEvaluator.Function(
      argtypes: [.nodesType],
      restype: .jsonType,
      impl: { root, current, args throws in
        switch args[0] {
          case .nodes(let nodes):
            return .json(.integer(Int64(nodes.count)))
          default:
            return .json(nil)
        }
      })
    self.functions["match"] = JSONPathEvaluator.Function(
      argtypes: [.jsonType, .jsonType],
      restype: .logicalType,
      impl: { root, current, args throws in
        guard case .json(.string(let str)) = args[0] else {
          throw JSONPathEvaluator.Error.jsonTypeMismatch("match", .string, args[0])
        }
        guard case .json(.string(let pattern)) = args[1] else {
          throw JSONPathEvaluator.Error.jsonTypeMismatch("match", .string, args[1])
        }
        let regex = try NSRegularExpression(pattern: pattern + "$")
        let range = NSRange(location: 0, length: str.utf16.count)
        return .logical(regex.firstMatch(in: str, options: [.anchored], range: range) != nil)
      })
    self.functions["search"] = JSONPathEvaluator.Function(
      argtypes: [.jsonType, .jsonType],
      restype: .logicalType,
      impl: { root, current, args throws in
        guard case .json(.string(let str)) = args[0] else {
          throw JSONPathEvaluator.Error.jsonTypeMismatch("search", .string, args[0])
        }
        guard case .json(.string(let pattern)) = args[1] else {
          throw JSONPathEvaluator.Error.jsonTypeMismatch("search", .string, args[1])
        }
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: str.utf16.count)
        return .logical(regex.firstMatch(in: str, options: [], range: range) != nil)
      })
    self.functions["value"] = JSONPathEvaluator.Function(
      argtypes: [.nodesType],
      restype: .jsonType,
      impl: { root, current, args throws in
        switch args[0] {
          case .nodes(let nodes):
            return nodes.count == 1 ? .json(nodes[0]) : .json(nil)
          default:
            return .json(nil)
        }
      })
    self.functions["values"] = JSONPathEvaluator.Function(
      argtypes: [.nodesType],
      restype: .jsonType,
      impl: { root, current, args throws in
        switch args[0] {
          case .nodes(let nodes):
            return .json(.array(nodes))
          default:
            return .json(nil)
        }
      })
    self.functions["subset"] = JSONPathEvaluator.Function(
      argtypes: [.jsonType, .jsonType],
      restype: .logicalType,
      impl: { root, current, args throws in
        guard case .json(.array(let sub)) = args[0] else {
          throw JSONPathEvaluator.Error.jsonTypeMismatch("subset", .array, args[0])
        }
        guard case .json(.array(let full)) = args[1] else {
          throw JSONPathEvaluator.Error.jsonTypeMismatch("subset", .array, args[1])
        }
        for elem in sub where !full.contains(elem) {
          return .logical(false)
        }
        return .logical(true)
      })
    self.functions["contains"] = JSONPathEvaluator.Function(
      argtypes: [.jsonType, .jsonType],
      restype: .logicalType,
      impl: { root, current, args throws in
        guard case .json(let e) = args[0], let elem = e else {
          return .logical(false)
        }
        guard case .json(.array(let full)) = args[1] else {
          throw JSONPathEvaluator.Error.jsonTypeMismatch("contains", .array, args[1])
        }
        return .logical(full.contains(elem))
      })
  }
  
  public func value(of ident: String) -> JSONPathEvaluator.Value? {
    return self.variables[ident]
  }
  
  public func function(name: String) -> JSONPathEvaluator.Function? {
    return self.functions[name]
  }
}
