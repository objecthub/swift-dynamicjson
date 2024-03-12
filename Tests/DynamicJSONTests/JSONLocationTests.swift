//
//  JSONLocationTests.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 11/03/2024.
//

import XCTest
@testable import DynamicJSON

final class JSONLocationTests: XCTestCase {

  func testSimpleLocations() throws {
    XCTAssertEqual(try? JSONPath(query: "$[3]").location, try? JSONLocation("$[3]"))
    XCTAssertEqual(try? JSONPath(query: "$[-3]").location, try? JSONLocation("$[-3]"))
    let location = try JSONLocation("$.foo.bar[1].goo[-2][0]")
    XCTAssertEqual(location, try JSONLocation(location.description))
    XCTAssertNotNil(try? JSONLocation("$.foo.bar[1].goo[2][0].too").pointer)
    XCTAssertNil(location.pointer)
  }
}
