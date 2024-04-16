//
//  JSONSchemaDialect.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 22/03/2024.
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
/// A `JSONSchemaDialect` gets identified by a URI. It provides a `validator` factory
/// method for instantiating validators for that dialect, given a root schema and
/// validation context.
///
public protocol JSONSchemaDialect {
  var uri: URL { get }
  func validator(for: JSONSchema, in: JSONSchemaValidationContext) -> JSONSchemaValidator
}

extension JSONSchemaDialect where Self == JSONSchemaDraft2020.Dialect {
  
  /// Default `draft2020` implementation (which ignores the "format" keyword).
  public static var draft2020: JSONSchemaDraft2020.Dialect {
    return JSONSchemaDraft2020.Dialect.default
  }
  
  /// Frequently used variant of `draft2020` which validates strings via the "format" keyword.
  public static var draft2020Format: JSONSchemaDraft2020.Dialect {
    return JSONSchemaDraft2020.Dialect.validateFormat
  }
}
