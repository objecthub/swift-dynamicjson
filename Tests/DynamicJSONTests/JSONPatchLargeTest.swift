//
//  JSONPatchLargeTest.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 05/04/2024.
//

import Foundation
import XCTest
import DynamicJSON

final class JSONPatchLargeTest: XCTestCase {

  private func jsonFileURL(_ filename: String) throws -> URL? {
    let bundle = Bundle(for: type(of: self))
    guard let url = bundle.url(forResource: filename,
                               withExtension: "json",
                               subdirectory: "JSONPatch") else {
      return nil
    }
    return url
  }
  
  private func loadJSON(_ filename: String) throws -> JSON? {
    guard let url = try self.jsonFileURL(filename) else {
      return nil
    }
    return try JSON(url: url)
  }
  
  func testLargeJson() throws {
    if let source = try self.loadJSON("bigexample1"),
       let target = try self.loadJSON("bigexample2"),
       let patchUrl = try self.jsonFileURL("bigpatch") {
      let patch = try JSONPatch(url: patchUrl)
      let result = try source.applying(patch: patch)
      XCTAssertEqual(result, target)
    } else {
      XCTFail("large test setup broken")
    }
  }
  
  func testLargeJsonPerformance() throws {
    guard let source = try self.loadJSON("bigexample1"),
          let target = try self.loadJSON("bigexample2"),
          let patchUrl = try self.jsonFileURL("bigpatch") else {
      XCTFail("large test setup broken")
      return
    }
    measure {
      let patch = try! JSONPatch(url: patchUrl)
      for _ in 0...9 {
        let result = try! source.applying(patch: patch)
        XCTAssertEqual(result, target)
      }
    }
  }
}
