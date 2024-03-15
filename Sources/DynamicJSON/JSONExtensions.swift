//
//  JSONExtensions.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 13/02/2024.
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

extension Encodable {
  
  /// Returns a JSON representation for this encodable object, if encoding
  /// as JSON succeeds; otherwise `nil` is returned.
  var jsonValue: JSON? {
    return try? JSON(encodable: self)
  }
}

extension Decodable {
  
  /// Initializes a new value given the JSON representation `json`.
  init?(_ json: JSON?) {
    if let value: Self = try? json?.coerce() {
      self = value
    } else {
      return nil
    }
  }
}
