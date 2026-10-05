//
//  Schema.swift
//  WikiWatch
//
//  Created by Matthias Zenger on 05/10/2026.
//  Copyright © 2026 Matthias Zenger. All rights reserved.
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
import DynamicJSON

// HOW TO VALIDATE JSON WITH A JSON SCHEMA
// =======================================
//
// DynamicJSON implements JSON Schema (draft 2020-12). Validating a JSON value takes three steps:
//
//   1. Load the schema. A schema is itself a JSON document. `JSONSchemaResource` wraps a
//      top-level schema, checks it, and gives it an identity (its `$id`). Besides
//      `JSONSchemaResource(string:)`, there are initializers for `Data` and `URL`.
//   2. Create a `JSONSchemaRegistry`. A registry knows the schemas and schema dialects that are
//      available, and resolves references (`$ref`) between schemas. It also decides how strict
//      validation is: with the default dialect `.draft2020`, the `format` keyword is only
//      an annotation, with `.draft2020Format`, a string that does not match its `format`
//      (e.g. `date-time`) is invalid.
//   3. Ask the registry for a `JSONSchemaValidator` and call `validate(_:)` for every
//      JSON value you want to check. Creating a validator is the expensive part. Create it
//      once, and reuse it for all values, as the pipeline of this tool does.
//
// For one-off checks, there is a shortcut on `JSON` itself: `json.valid(for: schema)` and
// `json.validate(with: schema)`.

///
/// A JSON Schema for the events of the `recentchange` stream. It only describes the fields
/// `WikiWatch` relies on; further fields are allowed. Events that do not conform to this
/// schema are counted, but not processed any further.
///
enum RecentChangeSchema {
  
  // The schema is an ordinary JSON document, here embedded as a raw string literal. Note:
  //   - `$id` identifies the schema; other schemas could refer to it with `$ref`.
  //   - `$schema` selects the dialect (the version of the JSON Schema language).
  //   - `required` lists properties that have to be present; `properties` constrains the
  //     values of properties if they are present. Properties that are not mentioned are
  //     allowed (this is the default of JSON Schema).
  //   - `"type": ["integer", "null"]` allows alternatives.
  //   - `"format": "date-time"` is checked because we use the dialect `.draft2020Format`.
  static let source = #"""
    {
      "$id": "https://objecthub.com/wikiwatch/recentchange",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "title": "Wikimedia recent change",
      "type": "object",
      "required": ["type", "wiki", "meta"],
      "properties": {
        "type": { "type": "string" },
        "wiki": { "type": "string", "minLength": 1 },
        "title": { "type": "string" },
        "user": { "type": "string" },
        "bot": { "type": "boolean" },
        "minor": { "type": "boolean" },
        "timestamp": { "type": "integer" },
        "length": {
          "type": "object",
          "properties": {
            "old": { "type": ["integer", "null"] },
            "new": { "type": "integer" }
          }
        },
        "meta": {
          "type": "object",
          "required": ["domain", "dt"],
          "properties": {
            "domain": { "type": "string" },
            "dt": { "type": "string", "format": "date-time" }
          }
        }
      }
    }
    """#
  
  /// Creates a validator for recent change events. Format annotations (here: the `date-time`
  /// format of `meta.dt`) are validated as well.
  static func makeValidator() throws -> JSONSchemaValidator {
    // The registry decides which dialect is used for schemas that do not declare one.
    // `.draft2020Format` is the 2020-12 dialect with format validation turned on.
    let registry = JSONSchemaRegistry(defaultDialect: .draft2020Format)
    // Parse and check the schema. This throws if the schema is malformed.
    let resource = try JSONSchemaResource(string: self.source)
    // Registering the resource makes it known to the registry (needed if other schemas refer
    // to it) and returns a validator for it. If the schema was stored in a file, one could
    // call `registry.loadSchema(from: url)` instead, or make a whole directory of schema files
    // available with a `JSONSchemaProvider` (see `registry.register(provider:)`).
    return try registry.validator(for: resource)
  }
}
