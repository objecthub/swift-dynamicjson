//
//  Extensions.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 11.02.2024.
//

import Foundation

extension NSNumber {

  /// Boolean value indicating whether this `NSNumber` wraps a boolean.
  ///
  /// For example, when using `NSJSONSerialization` Bool values are converted into `NSNumber` instances.
  ///
  /// - seealso: https://stackoverflow.com/a/49641315/3589408
  internal var isBool: Bool {
    let objCType = String(cString: self.objCType)
    if (self.compare(trueNumber) == .orderedSame && objCType == trueObjCType) ||
        (self.compare(falseNumber) == .orderedSame && objCType == falseObjCType) {
      return true
    } else {
      return false
    }
  }
}

private let trueNumber = NSNumber(value: true)
private let falseNumber = NSNumber(value: false)
private let trueObjCType = String(cString: trueNumber.objCType)
private let falseObjCType = String(cString: falseNumber.objCType)
