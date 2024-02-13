//
//  JSONError.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 11.02.2024.
//

import Foundation

enum JSONError: Error {
  case initialization
  case erroneousEncoding
  case invalidKeyPath
  case erroneousIndexSelection(JSON, Int)
  case erroneousKeySelection(JSON, String)
}
