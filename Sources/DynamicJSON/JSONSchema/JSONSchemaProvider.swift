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

public protocol JSONSchemaProvider {
  func resource(for id: JSONSchemaIdentifier) -> JSONSchemaResource?
}

extension JSONSchemaProvider where Self == StaticJSONSchemaFileProvider {
  public static func files(from directory: URL,
                           base uri: JSONSchemaIdentifier) -> StaticJSONSchemaFileProvider {
    return StaticJSONSchemaFileProvider(directory: directory, base: uri)
  }
}

public struct StaticJSONSchemaFileProvider: JSONSchemaProvider, CustomStringConvertible {
  public let fileUrls: [JSONSchemaIdentifier : URL]
  
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
