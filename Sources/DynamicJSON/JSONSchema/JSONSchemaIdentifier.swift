//
//  JSONSchemaIdentifier.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 31/03/2024.
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
/// URI representing a JSON schema identifier.
///
public struct JSONSchemaIdentifier: Codable, Hashable, CustomStringConvertible {
  public let uri: URLComponents
  
  /// Initialize URI from a string.
  public init?(string: String) {
    guard let uri = URLComponents(string: string) else {
      return nil
    }
    self.uri = uri
  }
  
  /// Initialize URI from a path and a segment.
  public init(path: String, fragment: String? = nil) {
    var uri = URLComponents()
    uri.percentEncodedPath = path
    uri.fragment = fragment
    self.uri = uri
  }
  
  /// Initialize URI from a `URLComponents` value.
  public init(uri: URLComponents) {
    self.uri = uri
  }
  
  /// Initialize URI from a `URL` value.
  public init?(url: URL, resolvingAgainstBaseURL: Bool = true) {
    guard let uri = URLComponents(url: url, resolvingAgainstBaseURL: resolvingAgainstBaseURL) else {
      return nil
    }
    self.uri = uri
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let object = try? container.decode(String.self),
       let res = URLComponents(string: object) {
      self.uri = res
    } else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: decoder.codingPath,
                              debugDescription: "Invalid JSONSchema encoding"))
    }
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.uri.string ?? self.uri.description)
  }
  
  /// Is this an absolute URI?
  public var isAbsolute: Bool {
    return self.uri.scheme != nil || self.uri.host != nil
  }
  
  /// Is this a base URI?
  public var isBaseIdentifier: Bool {
    return self.uri.fragment == nil
  }
  
  /// Is this URI empty (i.e. it has no scheme, no host, no port, no path, and no fragment)?
  public var isEmpty: Bool {
    return self.uri.scheme == nil && self.uri.host == nil && self.uri.port == nil &&
           self.uri.path.isEmpty && self.uri.fragment == nil
  }
  
  /// Path of this URI.
  public var path: String {
    return self.uri.path
  }
  
  /// Last path component of this URI.
  public var lastPathComponent: String {
    let path = self.percentEncodedPath
    if let index = path.lastIndex(of: "/") {
      let res = String(path[path.index(after: index)..<path.endIndex])
      return res.removingPercentEncoding ?? res
    } else {
      return self.uri.path
    }
  }
  
  /// Fragment of this URI.
  public var fragment: String? {
    return self.uri.fragment
  }
  
  /// Path in percent-encoded form.
  public var percentEncodedPath: String {
    return self.uri.percentEncodedPath
  }
  
  /// Fragment in percent-encoded form.
  public var percentEncodedFragment: String? {
    return self.uri.percentEncodedFragment
  }
  
  /// Base identifier, i.e. ignoring fragments.
  public var baseIdentifier: JSONSchemaIdentifier {
    var res = self.uri
    res.fragment = nil
    return JSONSchemaIdentifier(uri: res)
  }
  
  /// Interpret this `JSONSchemaIdentifier` relative to `base` and return this interpretation
  /// as a new `JSONSchemaIdentifier`.
  public func relative(to base: JSONSchemaIdentifier?) -> JSONSchemaIdentifier {
    guard let base, !self.isAbsolute else {
      return self
    }
    guard !self.isEmpty else {
      return base
    }
    var res = self.uri
    res.scheme = base.uri.scheme
    res.host = base.uri.host
    res.port = base.uri.port
    if let first = self.uri.percentEncodedPath.first, first != "/" {
      var path = base.uri.percentEncodedPath
      if path.isEmpty {
        path.append("/")
      }
      if path.last == "/" {
        res.percentEncodedPath = path + self.uri.percentEncodedPath
      } else if let index = path.lastIndex(of: "/") {
        res.percentEncodedPath = path[path.startIndex...index] + self.uri.percentEncodedPath
      } else {
        res.percentEncodedPath = self.uri.percentEncodedPath
      }
    }
    return JSONSchemaIdentifier(uri: res)
  }
  
  /// The URI as a string.
  public var string: String {
    return self.uri.string ?? self.uri.description
  }
  
  public var description: String {
    return self.uri.description
  }
}
