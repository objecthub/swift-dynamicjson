//
//  JSONType.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 19/02/2024.
//

import Foundation

public enum JSONType: Hashable, CustomStringConvertible {
  case null
  case boolean
  case number
  case string
  case array
  case object
  
  public var description: String {
    switch self {
      case .null:
        return "Null"
      case .boolean:
        return "Boolean"
      case .number:
        return "Number"
      case .string:
        return "String"
      case .array:
        return "Array"
      case .object:
        return "Object"
    }
  }
}
