//
//  JSONMergingTests.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 05/04/2024.
//

import XCTest
import DynamicJSON

final class JSONMergingTests: XCTestCase {
  
  func testSimple() throws {
    let target = try JSON(string: """
    {
      "title": "Goodbye!",
      "author": {
        "givenName": "John",
        "familyName": "Doe"
      },
      "tags": [
        "example",
        "sample"
      ],
      "content": "This will be unchanged"
    }
    """)
    let patch = try JSON(string: """
    {
        "title": "Hello!",
        "author": {
          "familyName": null
        },
        "phoneNumber": "+01-123-456-7890",
        "tags": ["example"]
    }
    """)
    let expected = try JSON(string: """
    {
      "title": "Hello!",
      "author": {
        "givenName": "John"
      },
      "tags": [
        "example"
      ],
      "content": "This will be unchanged",
      "phoneNumber": "+01-123-456-7890"
    }
    """)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldMergeObjectsAndOverrideMember() throws {
    let target = try JSON(string: "{\"a\": \"b\", \"c\": {\"d\": \"e\", \"f\": \"g\"}}")
    let patch = try JSON(string: "{\"a\": \"z\", \"c\": {\"f\": null}}")
    let expected = try JSON(string: "{\"a\": \"z\", \"c\": {\"d\": \"e\"}}")
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldOverrideFieldInObject() throws {
    let target = try JSON(string: #"{"a": "b"}"#)
    let patch = try JSON(string: #"{"a": "c"}"#)
    let expected = try JSON(string: #"{"a": "c"}"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldAddFieldToObject() throws {
    let target = try JSON(string: #"{"a": "b"}"#)
    let patch = try JSON(string: #"{"b": "c"}"#)
    let expected = try JSON(string: #"{"a": "b", "b": "c"}"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldRemoveFieldFromObject() throws {
    let target = try JSON(string: #"{"a": "b", "b": "c"}"#)
    let patch = try JSON(string: #"{"a": null}"#)
    let expected = try JSON(string: #"{"b": "c"}"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldOverrideFieldInArray() throws {
    let target = try JSON(string: #"{"a": ["b"]}"#)
    let patch = try JSON(string: #"{"a": "c"}"#)
    let expected = try JSON(string: #"{"a": "c"}"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldReplaceArrayWithScalar() throws {
    let target = try JSON(string: #"{"a": "c"}"#)
    let patch = try JSON(string: #"{"a": ["b"]}"#)
    let expected = try JSON(string: #"{"a": ["b"]}"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldMergeObjectsInObject() throws {
    let target = try JSON(string: #"{"a": {"b": "c"}}"#)
    let patch = try JSON(string: #"{"a": {"b": "d", "c": null}}"#)
    let expected = try JSON(string: #"{"a": {"b": "d"}}"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldReplaceArrayWithValue() throws {
    let target = try JSON(string: #"{"a": [{"b": "c"}]}"#)
    let patch = try JSON(string: #"{"a": [1]}"#)
    let expected = try JSON(string: #"{"a": [1]}"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldMergeNestedObjectsAndRemoveLeafNodes() throws {
    let target = try JSON(string: #"{}"#)
    let patch = try JSON(string: #"{"a": {"bb": {"ccc": null}}}"#)
    let expected = try JSON(string: #"{"a": {"bb": {}}}"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldReplaceScalarWithScalar() throws {
    let target = try JSON(string: #"{"a": "b"}"#)
    let patch = try JSON(string: #"["c"]"#)
    let expected = try JSON(string: #"["c"]"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldReplaceScalarWithNull() throws {
    let target = try JSON(string: #"{"a": "foo"}"#)
    let patch = try JSON(string: #"null"#)
    let expected = try JSON(string: #"null"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldReplaceScalarWithString() throws {
    let target = try JSON(string: #"{"a": "foo"}"#)
    let patch = try JSON(string: #""bar""#)
    let expected = try JSON(string: #""bar""#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldMergeNullWithScalar() throws {
    let target = try JSON(string: #"{"e": null}"#)
    let patch = try JSON(string: #"{"a": 1}"#)
    let expected = try JSON(string: #"{"e": null, "a": 1}"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldReplaceArrayWithObject() throws {
    let target = try JSON(string: #"{"a": []}"#)
    let patch = try JSON(string: #"{"a": {"b": "c"}}"#)
    let expected = try JSON(string: #"{"a": {"b": "c"}}"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldMergeObjectsInArray() throws {
    let target = try JSON(string: #"{"a": []}"#)
    let patch = try JSON(string: #"{"a": {"b": "c"}}"#)
    let expected = try JSON(string: #"{"a": {"b": "c"}}"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldReplaceObjectWithArray() throws {
    let target = try JSON(string: #"{"a": {"b": "c"}}"#)
    let patch = try JSON(string: #"{"a": []}"#)
    let expected = try JSON(string: #"{"a": []}"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldMergeArrays() throws {
    let target = try JSON(string: #"["a", "b"]"#)
    let patch = try JSON(string: #"["c", "d"]"#)
    let expected = try JSON(string: #"["c", "d"]"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldRemoveKeyFromObject() throws {
    let target = try JSON(string: #"{"a": "b"}"#)
    let patch = try JSON(string: #"{"a": null}"#)
    let expected = try JSON(string: #"{}"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  /*
  func testPatchShouldRemoveIndexFromArray() throws {
    let target = try JSON(string: #"["a", "b"]"#)
    let patch = try JSON(string: #"{"1": null}"#)
    let expected = try JSON(string: #"["a"]"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  
  func testPatchShouldRemoveArrayElement() throws {
    let target = try JSON(string: #"[1, 2, 3]"#)
    let patch = try JSON(string: #"[null, 2]"#)
    let expected = try JSON(string: #"[2]"#)
    let result = target.merging(patch: patch)
    XCTAssertEqual(result, expected)
  }
  */
}
