# Accessing JSON Values

Navigate to values within a JSON document using member lookup, subscripts, JSON locations,
and JSON pointers.

## Overview

A value within a larger JSON document can be accessed as if the data was fully structured.
The following expressions all return the JSON value `1`, the first element of array `arr` in
`object` of the document `json1` from <doc:RepresentingJSON>:

- **Dynamic member lookup:** `json1.object?.arr?[0]`
- **Key path lookup:** `json1[keyPath: \.object?.arr?[0]]`
- **Subscript lookup:** `json1["object"]?["arr"]?[0]`
- **Reference lookup:**
  - Using a JSON Pointer string: `try json1[ref: "/object/arr/0"]`
  - Using a JSON Path string: `try json1[ref: "$.object.arr[0]"]`
  - Using an implementation of ``JSONReference``, such as ``JSONPointer`` and
    ``JSONLocation``: `json1[ref: p]`

### JSON references

Components of a JSON value are identified by implementations of the protocols
``JSONReference`` and ``SegmentableJSONReference``:

```swift
protocol JSONReference: CustomStringConvertible {
  // Returns a new JSONReference with the given member selected.
  func select(member: String) -> Self
  // Returns a new JSONReference with the given index selected.
  func select(index: Int) -> Self
  // Retrieve value at which this reference is pointing from JSON document `value`.
  func get(from value: JSON) -> JSON?
  // Replace value at which this reference is pointing with `json` within `value`.
  func set(to json: JSON, in value: JSON) throws -> JSON
  // Mutate value at which this reference is pointing within JSON document `value`
  // with function `proc`.
  func mutate(_ json: inout JSON, with proc: (inout JSON) throws -> Void,
              insert: Bool) throws
}

protocol SegmentableJSONReference: JSONReference {
  associatedtype Segment: JSONReferenceSegment
  // An array of segments representing the reference.
  var segments: [Segment] { get }
  // Creates a new `SegmentableJSONReference` on top of this reference.
  func select(segment: Segment) -> Self
  // Decomposes this reference into the top segment selector and its parent.
  var deselect: (Self, Segment)? { get }
}
```

_DynamicJSON_ provides two implementations of ``SegmentableJSONReference``:
``JSONPointer`` and ``JSONLocation``, an abstraction equivalent to singular _JSON Path_
queries.

Reference strings are interpreted by ``JSON/reference(from:)``: strings starting with `/`
are parsed as ``JSONPointer``; all other non-empty strings as ``JSONLocation`` (the leading
`$` may be omitted); the empty string refers to the root.

### JSON Location

``JSONLocation`` is the default way of identifying JSON values within a JSON document. It
is based on how values are identified in
[JSON Path](https://datatracker.ietf.org/doc/html/rfc9535/) and uses a restricted form of
the JSON Path query syntax. A ``JSONLocation`` refers to at most one value within a document
and is defined as a sequence of member names and array indices:

```swift
indirect enum JSONLocation: SegmentableJSONReference, Codable, Hashable, CustomStringConvertible {
  case root
  case member(JSONLocation, String)
  case index(JSONLocation, Int)

  enum Segment: JSONReferenceSegment, Codable, Hashable, CustomStringConvertible {
    case member(String)
    case index(Int)
    ...
  }
  ...
}
```

Each location starts with `$`, the root of the document. Members can be expressed with dot
notation or with bracket notation; array indices always use brackets:

```
$.store.book[0].title
$['store']['book'][0]['title']
$['store'].book[-1].title
```

Negative indices are offsets from the end of an array, with `-1` referring to the last
element.

Locations can be created from strings or from segments:

```swift
let r1 = try JSONLocation("$['store']['book'][0]['title']")
let r2 = JSONLocation(segments: [.member("store"),
                                 .member("book"),
                                 .index(0),
                                 .member("title")])
```

Useful members of ``JSONLocation`` include ``JSONLocation/select(member:)``,
``JSONLocation/select(index:)``, ``JSONLocation/select(segment:)``,
``JSONLocation/pointer`` (a matching ``JSONPointer``, if one exists),
``JSONLocation/path`` (a matching ``JSONPath`` query), ``JSONLocation/get(from:)``,
``JSONLocation/set(to:in:)`` and ``JSONLocation/mutate(_:with:insert:)``.

### JSON Pointer

_JSON Pointer_ is specified by [RFC 6901](https://datatracker.ietf.org/doc/html/rfc6901/)
and is the most established formalism for referring to a value within a JSON document. It
is designed to be easily embedded in JSON string values and URI fragment identifiers
(see [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986/)).

A JSON pointer is a path starting at the root of a document. Each path element is prefixed
with `/` and either refers to an object member or an array index. `~1` encodes `/` in member
names and `~0` encodes `~`. The empty string refers to the root.

```
/store/book/0/title
```

JSON Pointer neither distinguishes array indices from numeric member names — `/0` can select
index 0 of an array or member `"0"` of an object — nor supports negative indices. Thus, there
is no general mapping between JSON locations and JSON pointers;
``JSONPointer/locations()`` returns all locations a pointer could correspond to.

``JSONPointer`` is a struct with ``JSONPointer/ReferenceToken`` segments:

```swift
struct JSONPointer: SegmentableJSONReference, Codable, Hashable, CustomStringConvertible {
  let segments: [ReferenceToken]

  enum ReferenceToken: JSONReferenceSegment, Hashable, CustomStringConvertible {
    case member(String)
    case index(String, Int?)
    ...
  }
  ...
}
```

Pointers are created from strings or components:

```swift
let p1 = try JSONPointer("/store/book/0/title")
let p2 = JSONPointer(components: ["store", "book", "0", "title"])
```

Besides the ``JSONReference`` operations, ``JSONPointer`` provides
``JSONPointer/select(member:)``, ``JSONPointer/select(index:)``,
``JSONPointer/select(segment:)``, ``JSONPointer/deselect``, ``JSONPointer/components``, and
``JSONPointer/locations()``.

## Topics

### References

- ``JSONReference``
- ``SegmentableJSONReference``
- ``JSONReferenceSegment``
- ``JSONReferenceSegmentIndex``
- ``JSONReferenceError``
- ``JSONLocationConvertible``

### Locations and pointers

- ``JSONLocation``
- ``JSONPointer``
- ``LocatedJSON``

### Looking up values

- ``JSON/subscript(_:)-(Int)``
- ``JSON/subscript(dynamicMember:)``
- ``JSON/subscript(ref:)-(JSONReference)``
