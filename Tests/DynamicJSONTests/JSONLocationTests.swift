//
//  JSONLocationTests.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 11/03/2024.
//

import XCTest
@testable import DynamicJSON

final class JSONLocationTests: XCTestCase {
  
  struct Example {
    let store: Store
  }
  
  struct Store {
    let book: [Book]
  }
  
  struct Book {
    let title: String
  }
  
  func testInitializers() throws {
    let ref1 = try JSONLocation("$['store']['book'][0]['title']")
    let ref2 = JSONLocation(segments: [.member("store"), .member("book"), .index(0), .member("title")])
    XCTAssertEqual(ref1, ref2)
  }

  func testSimpleLocations() throws {
    XCTAssertEqual(try? JSONPath(query: "$[3]").location, try? JSONLocation("$[3]"))
    XCTAssertEqual(try? JSONPath(query: "$[-3]").location, try? JSONLocation("$[-3]"))
    let location = try JSONLocation("$.foo.bar[1].goo[-2][0]")
    XCTAssertEqual(location, try JSONLocation(location.description))
    XCTAssertNotNil(try? JSONLocation("$.foo.bar[1].goo[2][0].too").pointer)
    XCTAssertNil(location.pointer)
  }
  
  func testPrefixes() throws {
    let location = try JSONLocation("$.foo[2].bar.goo[4]")
    let prefix0 = try JSONLocation("$.foo[2].bar")
    let prefix1 = try JSONLocation("$.foo[2]")
    let prefix2 = try JSONLocation("$.foo")
    let prefix3 = try JSONLocation("$")
    XCTAssert(prefix0.isPrefix(of: location))
    XCTAssert(prefix1.isPrefix(of: location))
    XCTAssert(prefix2.isPrefix(of: location))
    XCTAssert(prefix3.isPrefix(of: location))
    XCTAssertEqual(location.relative(to: prefix0), try JSONLocation("$.goo[4]"))
    XCTAssertEqual(location.relative(to: prefix1), try JSONLocation("$.bar.goo[4]"))
    XCTAssertEqual(location.relative(to: prefix2), try JSONLocation("$[2].bar.goo[4]"))
    XCTAssertEqual(location.relative(to: prefix3), location)
  }
}
