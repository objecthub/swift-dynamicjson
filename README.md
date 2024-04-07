# Swift DynamicJSON

[![Platforms: macOS, iOS, Linux](https://img.shields.io/badge/Platforms-macOS,%20iOS,%20Linux-blue.svg?style=flat)](https://developer.apple.com/osx/) [![Language: Swift 5.9](https://img.shields.io/badge/Language-Swift%205.9-green.svg?style=flat)](https://developer.apple.com/swift/) [![IDE: Xcode 15](https://img.shields.io/badge/IDE-Xcode%2015-orange.svg?style=flat)](https://developer.apple.com/xcode/) [![Package managers: SwiftPM, Carthage](https://img.shields.io/badge/Package%20managers-SwiftPM,%20Carthage-8E64B0.svg?style=flat)](https://github.com/Carthage/Carthage) [![License: Apache](http://img.shields.io/badge/License-Apache-lightgrey.svg?style=flat)](https://raw.githubusercontent.com/objecthub/swift-numberkit/master/LICENSE)

_DynamicJSON_ is a framework for representing, querying, and manipulating generic JSON values. The framework provides:

   - A generic representation of JSON values as defined by [RFC 8259](https://datatracker.ietf.org/doc/html/rfc8259/).
   - A natural embedding of functionality for creating and manipulating JSON values into the Swift programming language, including support for reading and writing JSON data and for converting typed and untyped JSON representations.
   - An implementation of _JSON Pointer_ as defined by [RFC 6901](https://datatracker.ietf.org/doc/html/rfc6901/) for locating values within a JSON document.
   - An implementation of _JSON Path_ as defined by [RFC 9535](https://datatracker.ietf.org/doc/html/rfc9535/) for querying JSON data.
   - An implementation of _JSON Patch_ as defined by [RFC 6902](https://datatracker.ietf.org/doc/html/rfc6902/) for mutating JSON data.
   - An implementation of _JSON Merge Patch_ as defined by [RFC 7396](https://datatracker.ietf.org/doc/html/rfc7396/) for merging JSON data with JSON patches.
   - An implementation of _JSON Schema_ as defined by the [2020-12 Internet Draft specification](https://datatracker.ietf.org/doc/draft-bhutton-json-schema/) for validating JSON data.

## Representing JSON Data

All JSON values in framework _DynamicJSON_ are represented with enumeration [`JSON`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSON.swift).
Enumeration `JSON` defines the following cases:

```swift
public indirect enum JSON {
  case null
  case boolean(Bool)
  case integer(Int64)
  case float(Double)
  case string(String)
  case array([JSON])
  case object([String : JSON])
  ...
}
```

JSON values can be easily constructed using Swift literal syntax. Here is an example
for the initialization of a small JSON-based data structure:

```swift
let json0: JSON = [
  "foo": true,
  "str": "one two",
  "object": [
    "value": nil,
    "arr": [1, 2, 3],
    "obj": [ "x" : 17.6 ]
  ]
]
```

There are also [initializers](https://github.com/objecthub/swift-dynamicjson/blob/b53ea8d5a649a1132e44ac9ea9c20dd403549754/Sources/DynamicJSON/JSON.swift#L219)
to convert JSON encoded data in the form of a
[`String`](https://developer.apple.com/documentation/swift/string) or a
[`Data`](https://developer.apple.com/documentation/foundation/data) object into a
[`JSON`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSON.swift)
enumeration. The following code initializes a JSON value from a JSON encoded value in a String
literal.

```swift
let json1 = try JSON(string: """
  {
    "foo": true,
    "str": "one two",
    "object": {
      "value": null,
      "arr": [1, 2, 3],
      "obj": { "x" : 17.6 }
    }
  }
""")
```

Any encodable type can be converted into a JSON value using the initializer `init(encodable:)`.
Alternatively, `init()` can be used. This is the most generic initializer which can also
coerce basic types like `Bool`, `Int`, `String`, etc. into JSON.

```swift
struct Person: Codable {
  let name: String
  let age: Int
  let children: [Person]
}
let person = Person(name: "John", age: 34,
                    children: [ Person(name: "Sofia", age: 5, children: []) ])
let json2 = try JSON(encodable: person)
print(json2.description)
```

Executing this code will print the following JSON-based representation of `Person`:

```json
{
  "age" : 34,
  "children" : [
    {
      "age" : 5,
      "children" : [],
      "name" : "Sofia"
    }
  ],
  "name" : "John"
}
```

It is also possible to do the inverse, and convert a JSON-based representation
into a strongly typed data structure via method `coerce()`.

```swift
let json3: JSON = [
  "name": "Matthew",
  "age": 29,
  "children": []
]
let person2: Person = try json3.coerce()
```


## Accessing JSON Values

A JSON value within a larger JSON document can be identified and accessed using dynamic
member lookup as if the data was fully structured, e.g. by representing it as a struct.
Here are several examples showcasing the different ways how to access the first element
of array `arr` in `object` of `json1`. All expressions return the JSON value 1.

   - **Dynamic member lookup:** `json1.object?.arr?[0]`
   - **Keypath lookup:** `json1[keyPath: \.object?.arr?[0]]`
   - **Subscript lookup:** `json1["object"]?["arr"]?[0]`
   - **Reference lookup:**
      - Using JSON Pointer string: `try json1[ref: "/object/arr/0"]`
      - Using JSON Path string: `try json1[ref: "$.object.arr[0]"]`
      - Using implementations of [`JSONReference`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSONReference.swift), such as `JSONPointer` and `JSONPath`: `json1[ref: p]`, where `p` is an object of type `JSONReference`

In _DynamicJSON_, components of a JSON value are identified by implementations
of the protocols [`JSONReference`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSONReference.swift) and [`SegmentableJSONReference`](https://github.com/objecthub/swift-dynamicjson/blob/5a14f6e014116be9c95c68f0e3141d2605f95c5e/Sources/DynamicJSON/JSONReference.swift#L57). The following code presents the core methods implementing JSON references:

```swift
public protocol JSONReference: CustomStringConvertible {
  /// Returns a new JSONReference with the given member selected.
  func select(member: String) -> Self
  /// Returns a new JSONReference with the given index selected.
  func select(index: Int) -> Self
  /// Retrieve value at which this reference is pointing from JSON document `value`.
  func get(from value: JSON) -> JSON?
  /// Replace value at which this reference is pointing with `json` within `value`.
  func set(to json: JSON, in value: JSON) throws -> JSON
  /// Mutate value at which this reference is pointing within JSON document `value`
  /// with function `proc`.
  func mutate(_ json: inout JSON, with proc: (inout JSON) throws -> Void) throws
}

public protocol SegmentableJSONReference: JSONReference {
  associatedtype Segment: JSONReferenceSegment
  /// An array of segments representing the reference.
  var segments: [Segment] { get }
  /// Creates a new `SegmentableJSONReference` on top of this reference.
  func select(segment: Segment) -> Self
  /// Decomposes this reference into the top segment selector and its parent.
  var deselect: (Self, Segment)? { get }
}
```

_DynamicJSON_ currently provides two implementations of `SegmentableJSONReference`: [`JSONPointer`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSONPointer.swift) and [`JSONLocation`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSONLocation.swift), an abstraction that is equivalent to singular _JSON Path_ queries.

### Identifying values via JSON Location

[`JSONLocation`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSONLocation.swift) is the default implementation for identifying JSON values within a JSON document. It is based on how values are identified in [JSON Path](https://datatracker.ietf.org/doc/html/rfc9535/) and uses a restricted form of JSON Path query syntax.

A `JSONLocation` value is defined in terms of a sequence of member names and array indices used to navigate through the structure of a JSON document. `JSONLocation` references refer to at most one value within a JSON document. The following code summarizes how `JSONLocation` values are represented:

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

A JSON location is a path to an element in a JSON structure. Each element of the path is called a _segment_. The JSON location syntax supports two different forms to express such sequences of segments. Each sequence starts with `$` indicating the "root" of a JSON document. The most common form for expressing the segment sequence is using the dot notation:

```
$.store.book[0].title
```

While accessing an array index is always done using bracket notation, it is possible to also express the access of members of an object using bracket notation:

```
$['store']['book'][0]['title']
```

Is is also possible to mix the dot and bracket notation. Dots are only used before property names and never together with brackets:

```
$['store'].book[-1].title
```

The previous example also shows the usage of negative indices, which are interpreted as offsets
from the end of arrays with -1 referring to the last element.

The `JSONLocation` API supports multiple initializers for creating JSON location references:

```swift
let r1 = try JSONLocation("$['store']['book'][0]['title']")
let r2 = JSONLocation(segments: [.member("store"),
                                 .member("book"),
                                 .index(0),
                                 .member("title")])
```

This is a list of the most frequently used methods of `JSONLocation`:

```swift
public indirect enum JSONLocation: SegmentableJSONReference, ... {
  /// The segments defining this `JSONLocation`.
  var segments: [Segment]
  /// Returns a new JSONLocation with the given member selected.
  func select(member: String) -> JSONLocation
  /// Returns a new JSONLocation with the given index selected.
  func select(index: Int) -> JSONLocation
  /// Returns a new JSONLocation by appending the given segment.
  func select(segment: Segment) -> JSONLocation
  /// Returns a matching `JSONPointer` reference if possible.
  var pointer: JSONPointer?
  /// Returns a matching `JSONPath` query.
  var path: JSONPath
  /// Retrieve value at this location within `value`.
  func get(from value: JSON) -> JSON?
  /// Replace value at this location within `in` with `value`.
  func set(to json: JSON, in value: JSON) throws -> JSON
  /// Mutate value at this location within `value` with function `proc`.
  /// `proc` is provided a reference, enabling efficient in-place mutations.
  func mutate(_ json: inout JSON, with proc: (inout JSON) throws -> Void) throws
}
```

### Identifying values via JSON Pointer

_JSON Pointer_ is specified by [RFC 6901](https://datatracker.ietf.org/doc/html/rfc6901/) and
is generally the most established formalism for referring to a JSON value within a JSON document.
JSON Pointer is intended to be easily expressed in JSON string values as well as Uniform Resource
Identifier (URI) fragment identifiers (see [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986/)).

Like JSON Locations, each JSON Pointer specifies a path to an element in a JSON structure starting
with its root. Each element of the path either refers to an object member or an array index.
Syntactically, each path element is prefixed with "/". JSON Pointer uses "~1" to encode "/" in
member names and "~0" to encode "~". The empty string refers to the root of the JSON document.
Here is an example:

```
/store/book/0/title
```

JSON Pointer neither supports forcing an element such as "/0" to refer to an array index, nor
does it allow for negative indices (as an offset from the end of the array). All numeric path
elements such as "0" above can either match an array and select index 0 or they match an object
member "0". Thus, there is no general way to map JSON Location into JSON Pointer or vice versa.

Struct [`JSONPointer`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSONPointer.swift)
implements the JSON Pointer standard in the following way:

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

## Queries with JSON Path

## Mutating JSON Values

### JSON Mutation API

### Using JSON Patch

### Merging JSON Data

## Validating JSON Data

## Requirements

The following technologies are needed to build the _DynamicJSON_ framework. The library
and the command-line tool can both be built either using _Xcode_ or the _Swift Package Manager_.

- [Xcode 15](https://developer.apple.com/xcode/)
- [Swift 5.9](https://developer.apple.com/swift/)
- [Swift Package Manager](https://swift.org/package-manager/)

## Copyright

Author: Matthias Zenger (<matthias@objecthub.com>)  
Copyright © 2024 Matthias Zenger. All rights reserved.
