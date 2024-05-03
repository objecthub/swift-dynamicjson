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
    if let url = bundle.url(forResource: filename,
                            withExtension: "json",
                            subdirectory: "JSONPatch") {
      return url
    }
    let url = URL(fileURLWithPath: "Tests/DynamicJSONTests/ComplianceTests/JSONPatch/\(filename).json")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }
  
  private func loadJSON(_ filename: String) throws -> JSON? {
    guard let url = try self.jsonFileURL(filename) else {
      return nil
    }
    return try JSON(url: url)
  }
  
  func testExample() throws {
    let jsonstr = """
      [
        { "op": "test", "path": "/a/b/c", "value": "foo" },
        { "op": "remove", "path": "/a/b/c" },
        { "op": "add", "path": "/a/b/c", "value": [ "foo", "bar" ] },
        { "op": "replace", "path": "/a/b/c", "value": 42 },
        { "op": "move", "from": "/a/b/c", "path": "/a/b/d" },
        { "op": "copy", "from": "/a/b/d", "path": "/a/b/e" }
      ]
      """
    let patch = try JSONPatch(string: jsonstr)
    var json: JSON = [
      "a": [],
      "b": 5,
      "c": "stop"
    ]
    try? json.apply(patch: patch)
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
