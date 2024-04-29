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
  
  func testSymmetricalMergeBasics() throws {
    let a = try JSON(string: #"{"a": {"c": 1}}"#)
    XCTAssertEqual(a.merging(value: a), a)
    let b = try JSON(string: #"{"a": {"d": 2}, "b": 3}"#)
    XCTAssertEqual(b.merging(value: b), b)
    let e = try JSON(string: #"{"a": {"c": 1, "d": 2}, "b": 3}"#)
    let m0 = a.merging(value: b)
    let m1 = b.merging(value: a)
    XCTAssertEqual(m0, m1)
    XCTAssertEqual(m0, e)
  }
  
  func testSymmetricalMergeArrays() throws {
    let a = try JSON(string: #"[{"a": {"c": 1}}, "hello", [1]]"#)
    XCTAssertEqual(a.merging(value: a), a)
    let b = try JSON(string: #"[{"a": {"d": 2}, "b": 3}, "hello", [1]]"#)
    XCTAssertEqual(b.merging(value: b), b)
    let e = try JSON(string: #"[{"a": {"c": 1, "d": 2}, "b": 3}, "hello", [1]]"#)
    let m0 = a.merging(value: b)
    let m1 = b.merging(value: a)
    XCTAssertEqual(m0, m1)
    XCTAssertEqual(m0, e)
  }
  
  func testSymmetricalMergeObjects() throws {
    let a = try JSON(string: #"{"a": [1, {"b": 2}], "c": {"d": 3, "e": 4}}"#)
    XCTAssertEqual(a.merging(value: a), a)
    let b = try JSON(string: #"{"a": [1, {"f": "hello"}], "c": {"d": 3, "g": []}, "h": true}"#)
    XCTAssertEqual(b.merging(value: b), b)
    let e = try JSON(string: #"{"a": [1, {"b": 2, "f": "hello"}], "c": {"d": 3, "e": 4, "g": []}, "h": true}"#)
    let m0 = a.merging(value: b)
    let m1 = b.merging(value: a)
    XCTAssertEqual(m0, m1)
    XCTAssertEqual(m0, e)
  }
  
  func testRefinement() throws {
    let a = try JSON(string: #"""
      { "a": [1, {"b": 2}],
        "c": {"d": [{}]}}
    """#)
    let b = try JSON(string: #"""
      { "a": [1, {"b": 2, "e": 4}],
        "c": {"d": [{"f": 5}]}}
    """#)
    XCTAssert(b.isRefinement(of: a))
    let c = try JSON(string: #"""
      { "a": [1, {"e": 8}],
        "c": {"f": "hello"},
        "g": 9 }
    """#)
    let m = a.merging(value: c)
    let e = try JSON(string: #"""
      { "a": [1, {"b": 2, "e": 8}],
        "c": {"d": [{}], "f": "hello"},
        "g": 9 }
    """#)
    XCTAssertEqual(m, e)
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
