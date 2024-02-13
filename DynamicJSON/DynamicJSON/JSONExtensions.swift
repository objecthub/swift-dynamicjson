//
//  JSONExtensions.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 13.02.2024.
//

import Foundation

extension Encodable {
  var jsonValue: JSON? {
    return try? JSON(encodable: self)
  }
}
