//
//  JSONSchemaIdentifier.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 31/03/2024.
//

import Foundation

public struct JSONSchemaIdentifier: Codable, Hashable, CustomStringConvertible {
  public let uri: URLComponents
  
  public init?(string: String) {
    guard let uri = URLComponents(string: string) else {
      return nil
    }
    self.uri = uri
  }
  
  public init(path: String, fragment: String? = nil) {
    var uri = URLComponents()
    uri.percentEncodedPath = path
    uri.fragment = fragment
    self.uri = uri
  }
  
  public init(uri: URLComponents) {
    self.uri = uri
  }
  
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
  
  /*
  public init(from decoder: Decoder) throws {
    self.uri = try URLComponents(from: decoder)
  }

  public func encode(to encoder: Encoder) throws {
    try self.uri.encode(to: encoder)
  }
  */
  
  public var isAbsolute: Bool {
    return self.uri.scheme != nil || self.uri.host != nil
  }
  
  public var isBaseIdentifier: Bool {
    return self.uri.fragment == nil
  }
  
  public var path: String {
    return self.uri.path
  }
  
  public var lastPathComponent: String {
    let path = self.percentEncodedPath
    if let index = path.lastIndex(of: "/") {
      let res = String(path[path.index(after: index)..<path.endIndex])
      return res.removingPercentEncoding ?? res
    } else {
      return self.uri.path
    }
  }
  
  public var fragment: String? {
    return self.uri.fragment
  }
  
  public var percentEncodedPath: String {
    return self.uri.percentEncodedPath
  }
  
  public var percentEncodedFragment: String? {
    return self.uri.percentEncodedFragment
  }
  
  public var baseIdentifier: JSONSchemaIdentifier {
    var res = self.uri
    res.fragment = nil
    return JSONSchemaIdentifier(uri: res)
  }
  
  public func relative(to base: JSONSchemaIdentifier?) -> JSONSchemaIdentifier {
    guard let base, !self.isAbsolute else {
      return self
    }
    var res = self.uri
    res.scheme = base.uri.scheme
    res.host = base.uri.host
    res.port = base.uri.port
    if self.uri.percentEncodedPath.first != "/" {
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
  
  public var string: String {
    return self.uri.string ?? self.uri.description
  }
  
  public var description: String {
    return self.uri.description
  }
}
