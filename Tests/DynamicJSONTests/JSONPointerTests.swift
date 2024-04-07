//
//  JSONPointerTests.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 07/04/2024.
//

import XCTest
@testable import DynamicJSON

final class JSONPointerTests: XCTestCase {
  func testJSONPointerInit() throws {
    let p1 = try JSONPointer("/store/book/0/title")
    let p2 = JSONPointer(components: ["store", "book", "0", "title"])
    XCTAssertEqual(p1, p2)
  }
}
