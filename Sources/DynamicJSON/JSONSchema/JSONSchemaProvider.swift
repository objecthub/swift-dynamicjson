//
//  JSONSchemaProvider.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 29/03/2024.
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
/// A schema provider discovers and loads schema resources on demand. Registries consult
/// their providers for schemas that have not been registered explicitly.
///
public protocol JSONSchemaProvider {
  /// Returns the schema resource identified by `id`, or `nil` if this provider has none.
  func resource(for id: JSONSchemaIdentifier) -> JSONSchemaResource?
}

extension JSONSchemaProvider where Self == StaticJSONSchemaFileProvider {
  /// Returns a provider that discovers schema files below `directory`, mapping them to
  /// identifiers relative to `uri`. The directory is rescanned after `expiry` seconds.
  public static func files(from directory: URL,
                           base uri: JSONSchemaIdentifier,
                           expiry: TimeInterval = .infinity) -> JSONSchemaProvider {
    return JSONSchemaFileProvider(directory: directory, base: uri, expiry: expiry)
  }
  
  /// Returns a provider that discovers schema files below `directory` once, mapping them to
  /// identifiers relative to `uri`.
  public static func staticFiles(from directory: URL,
                                 base uri: JSONSchemaIdentifier) -> JSONSchemaProvider {
    return StaticJSONSchemaFileProvider(directory: directory, base: uri)
  }
}

///
/// A schema provider backed by a directory of JSON schema files. The directory gets
/// rescanned once `expiry` seconds have passed since the last scan.
///
open class JSONSchemaFileProvider: JSONSchemaProvider, CustomStringConvertible {
  /// The directory containing the schema files.
  public let directory: URL
  /// The base identifier schema file paths are resolved against.
  public let uri: JSONSchemaIdentifier
  /// The time interval after which the directory is rescanned.
  public let expiry: TimeInterval
  /// The time of the last directory scan.
  public var updateTime: Date
  /// The provider reflecting the state of the directory at the last scan.
  public var fileProvider: StaticJSONSchemaFileProvider
  
  /// Creates a provider for the schema files below `dir`, whose identifiers are relative to `uri`.
  public init(directory dir: URL,
              base uri: JSONSchemaIdentifier,
              expiry: TimeInterval = .infinity) {
    self.directory = dir
    self.uri = uri
    self.fileProvider = StaticJSONSchemaFileProvider(directory: dir, base: uri)
    self.expiry = expiry
    self.updateTime = .now
  }
  
  /// Returns the schema resource for `id`, or `nil` if no matching file exists.
  public func resource(for id: JSONSchemaIdentifier) -> JSONSchemaResource? {
    if Date.now.timeIntervalSince(self.updateTime) > self.expiry {
      self.update()
    }
    return self.fileProvider.resource(for: id)
  }
  
  /// Rescans the directory for schema files.
  public func update() {
    self.fileProvider = StaticJSONSchemaFileProvider(directory: self.directory, base: self.uri)
  }
  
  public var description: String {
    return self.fileProvider.description
  }
}

///
/// A schema provider backed by a snapshot of the schema files in a directory, taken
/// when the provider is created.
///
public struct StaticJSONSchemaFileProvider: JSONSchemaProvider, CustomStringConvertible {
  /// Maps schema identifiers to the URLs of the files defining them.
  public let fileUrls: [JSONSchemaIdentifier : URL]
  
  /// Creates a provider for the schema files below `dir`, whose identifiers are relative to `uri`.
  public init(directory dir: URL, base uri: JSONSchemaIdentifier) {
    var fileUrls: [JSONSchemaIdentifier : URL] = [:]
    var content: [(String, URL, Bool)] = Self.contents(of: dir)
    var i = 0
    while i < content.count {
      let (path, base, isDir) = content[i]
      if isDir {
        let url = URL(fileURLWithPath: path, isDirectory: isDir, relativeTo: base)
        content.append(contentsOf: Self.contents(of: url, path: path, base: base))
      } else {
        let id = JSONSchemaIdentifier(path: path).relative(to: uri)
        fileUrls[id] = URL(fileURLWithPath: path, relativeTo: base).absoluteURL
      }
      i += 1
    }
    self.fileUrls = fileUrls
  }
  
  /// Returns the schema resource for `id`, or `nil` if no matching file exists.
  public func resource(for id: JSONSchemaIdentifier) -> JSONSchemaResource? {
    guard let url = self.fileUrls[id] else {
      return nil
    }
    do {
      return try JSONSchemaResource(url: url, id: id)
    } catch {
      return nil
    }
  }
  
  public var description: String {
    var res = ""
    for (uri, url) in self.fileUrls {
      res += "\(url) --> \(uri)\n"
    }
    return res
  }
  
  private static func contents(of dir: URL,
                               path: String? = nil,
                               base: URL? = nil) -> [(String, URL, Bool)] {
    do {
      return try FileManager.default
        .contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])
        .map { url in
          ("\(path ?? "")\(path != nil ? "/" : "")\(url.lastPathComponent)",
           base ?? dir,
           url.isDirectory)
        }
    } catch {
      return []
    }
  }
}
