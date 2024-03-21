//
//  Indirect.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 19/03/2024.
//

import Foundation

@propertyWrapper
public class Indirect<Wrapped: Codable>: Codable {
  public let wrappedValue: Wrapped
  
  public init(wrappedValue: Wrapped) {
    self.wrappedValue = wrappedValue
  }
  
  required public init(from decoder: Decoder) throws {
    self.wrappedValue = try Wrapped(from: decoder)
  }
  
  public func encode(to encoder: Encoder) throws {
    try self.wrappedValue.encode(to: encoder)
  }
}

extension Indirect: Equatable where Wrapped: Equatable {
  public static func == (lhs: Indirect<Wrapped>, rhs: Indirect<Wrapped>) -> Bool {
    return lhs.wrappedValue == rhs.wrappedValue
  }
}

extension Indirect: Hashable where Wrapped: Hashable {
  public func hash(into hasher: inout Hasher) {
    return hasher.combine(self.wrappedValue)
  }
}
