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

<table width="100%">
<tr><th colspan="2">Table of contents</th></tr>
<tr>
<td width="600px" valign="top">
1. &nbsp;<a href="#representing-json-data">Representing JSON Data</a><br />
2. &nbsp;<a href="#accessing-json-values">Accessing JSON Values</a><br />
2.1 &nbsp;<a href="#json-location">JSON Location</a><br />
2.2 &nbsp;<a href="#json-pointer">JSON Pointer</a><br />
3. &nbsp;<a href="#queries-with-json-path">Queries with JSON Path</a><br />
</td>
<td width="50%" valign="top">
4. &nbsp;<a href="#mutating-json-values">Mutating JSON Values</a><br />
4.1 &nbsp;<a href="#mutation-api">Mutation API</a><br />
4.2 &nbsp;<a href="#json-patch">JSON Patch</a><br />
4.3 &nbsp;<a href="#json-merge-patch">JSON Merge Patch</a><br />
5. &nbsp;<a href="#validating-json-data">Validating JSON Data</a><br />
</td>
</tr>
</table>

&nbsp;

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
  func mutate(_ json: inout JSON, with proc: (inout JSON) throws -> Void) throws
}

public protocol SegmentableJSONReference: JSONReference {
  associatedtype Segment: JSONReferenceSegment
  // An array of segments representing the reference.
  var segments: [Segment] { get }
  // Creates a new `SegmentableJSONReference` on top of this reference.
  func select(segment: Segment) -> Self
  // Decomposes this reference into the top segment selector and its parent.
  var deselect: (Self, Segment)? { get }
}
```

_DynamicJSON_ currently provides two implementations of `SegmentableJSONReference`: [`JSONPointer`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSONPointer.swift) and [`JSONLocation`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSONLocation.swift), an abstraction that is equivalent to singular _JSON Path_ queries.

### JSON Location

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

`JSONLocation` defines the following frequently used methods:

```swift
public indirect enum JSONLocation: SegmentableJSONReference, ... {
  // The segments defining this `JSONLocation`.
  var segments: [Segment]
  // Returns a new JSONLocation with the given member selected.
  func select(member: String) -> JSONLocation
  // Returns a new JSONLocation with the given index selected.
  func select(index: Int) -> JSONLocation
  // Returns a new JSONLocation by appending the given segment.
  func select(segment: Segment) -> JSONLocation
  // Returns a matching `JSONPointer` reference if possible.
  var pointer: JSONPointer?
  // Returns a matching `JSONPath` query.
  var path: JSONPath
  // Retrieve value at this location within `value`.
  func get(from value: JSON) -> JSON?
  // Replace value at this location within `in` with `value`.
  func set(to json: JSON, in value: JSON) throws -> JSON
  // Mutate value at this location within `value` with function `proc`.
  // `proc` is provided a reference, enabling efficient in-place mutations.
  func mutate(_ json: inout JSON, with proc: (inout JSON) throws -> Void) throws
}
```

### JSON Pointer

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

The `JSONPointer` API supports multiple initializers for creating JSON Pointer references:

```swift
let p1 = try JSONPointer("/store/book/0/title")
let p2 = JSONPointer(components: ["store", "book", "0", "title"])
```

`JSONPointer` defines the following frequently used methods:

```swift
struct JSONPointer: SegmentableJSONReference, ... {
  // Returns this JSONPointer as an array of reference tokens.
  var segments: [ReferenceToken]
  // Returns a new JSONPointer with the given member selected.
  func select(member: String) -> JSONPointer
  // Returns a new JSONPointer with the given index selected.
  func select(index: Int) -> JSONPointer
  // Constructs a new JSONPointer by appending the given segment to this pointer.
  func select(segment: ReferenceToken) -> JSONPointer
  // Decomposes this JSONPointer into a parent pointer and a selector reference token.
  var deselect: (JSONPointer, ReferenceToken)?
  // The reference tokens defining this `JSONPointer` value.
  var components: [String]
  // Returns all JSON locations corresponding to this `JSONPointer`.
  func locations() -> [JSONLocation]
  // Retrieve value at which this reference is pointing from JSON document `value`.
  func get(from value: JSON) -> JSON?
  // Replace value at which this reference is pointing with `json` within `value`.
  func set(to json: JSON, in value: JSON) throws -> JSON
  // Mutate value at this location within `value` with function `proc`. `proc`
  // is provided a reference, enabling efficient, in-place mutations.
  func mutate(_ json: inout JSON, with proc: (inout JSON) throws -> Void) throws
}
```

## Queries with JSON Path

DynamicJSON supports the full _JSON Path_ standard as defined by [RFC 9535](https://datatracker.ietf.org/doc/html/rfc9535/).
Enum [`JSONPath`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSONPath/JSONPath.swift)
represents JSON Path queries.
[`JSON`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSON.swift)
provides `query()` methods to apply a JSON Path query to a JSON value.

To illustrate the usage of JSON Path queries, the following JSON value is being defined (this
is the example from RFC 9535):

```swift
let jval = try JSON(string: """
  { "store": {
      "book": [
        { "category": "reference",
          "author": "Nigel Rees",
          "title": "Sayings of the Century",
          "price": 8.95 },
        { "category": "fiction",
          "author": "Evelyn Waugh",
          "title": "Sword of Honour",
          "price": 12.99 },
        { "category": "fiction",
          "author": "Herman Melville",
          "title": "Moby Dick",
          "isbn": "0-553-21311-3",
          "price": 8.99 },
        { "category": "fiction",
          "author": "J. R. R. Tolkien",
          "title": "The Lord of the Rings",
          "isbn": "0-395-19395-8",
          "price": 22.99 }
      ],
      "bicycle": {
        "color": "red",
        "price": 399
      }
    }
  }
  """)
```

Now a JSON Path query `$.store.book[?@.price < 10].title` can be defined by using the
`JSONPath(query:strict:)` initializer. Finally, the path can be applied to `jval` by
invoking its `query()` method. The result is an array of
[`LocatedJSON`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/LocatedJSON.swift)
values matching the query within `jval`.
[`LocatedJSON`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/LocatedJSON.swift)
combines a location where a value was found with the value at that location into one object.

```swift
let path = try JSONPath(query: "$.store.book[?@.price < 10].title")
var results = try value.query(path)
for result in results {
  print(result)
}
```

This is the output generated from this code. It prints two `LocatedJSON` objects for the two
values within `jval` matching the query `path`.

```swift
$['store']['book'][0]['title'] => "Sayings of the Century"
$['store']['book'][2]['title'] => "Moby Dick"
```

If only locations or only values are needed as a result of evaluating a JSON Path query, then
it is possible to use the `query(locations:)` or `query(values:)` methods of `JSON`.

The above API supports the default JSON Path query language. JSON Path has a built-in
extensibility mechanism that lets one add custom functions, applicable in query filters.
This can be achieved by extending class
[`JSONPathEnvironment`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSONPath/JSONPathEnvironment.swift)
and overriding method `initialize()`. Such an extended environment can then be passed to
the initializer of struct 
[`JSONPathEvaluator`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSONPath/JSONPathEvaluator.swift),
which provides a means to execute queries using the extended environment.

## Mutating JSON Values

### Mutation API

_DynamicJSON_ represents JSON data with value type
[`JSON`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSON.swift).
There are a number of methods that mutate such data without copies being created. These are listed
in the code snippet below.

```swift
enum JSON: Hashable, .. {
  // Mutates this JSON value if it represents either an array or a string by
  // appending the given JSON value `json`. For arrays, `json` is appended as a
  // new element. For strings it is expected that `json` also refers to a string
  // and `json` gets appended as a string. For all other types of JSON values,
  // an error is thrown.
  mutating func append(_ json: JSON) throws
  
  // Mutates this JSON value if it represents either an array or a string by
  // inserting the given JSON value `json`. For arrays, `json` is inserted as a
  // new element at `index`. For strings it is expected that `json` also refers to
  // a string and `json` gets inserted into this string at position `index`. For
  // all other types of JSON values, an error is thrown.
  mutating func insert(_ json: JSON, at index: Int) throws
  
  // Adds a new key/value mapping or updates an existing key/value mapping in this
  // JSON object. If this JSON value is not an object, an error is thrown.
  mutating func assign(_ member: String, to json: JSON) throws
  
  // Replaces the value the location reference `ref` is referring to with `json`.
  // The replacement is done in place, i.e. it mutates this JSON value. `ref` can
  // be implemented by any abstraction implementing the `JSONReference` procotol.
  mutating func update(_ ref: JSONReference, with json: JSON) throws
  
  // Replaces the value the location reference string `ref` is referring to with
  // `json`. The replacement is done in place, i.e. it mutates this JSON value.
  // `ref` is a string representation of either `JSONLocation` or `JSONPointer`
  // references.
  mutating func update(_ ref: String, with json: JSON) throws
  
  // Mutates the JSON value the reference `ref` is referring to with function
  // `proc`. `proc` receives a reference to the JSON value, allowing efficient in
  // place mutations without automatically doing any copying. `ref` can be
  // implemented by any abstraction implementing the `JSONReference` procotol.
  mutating func mutate(_ ref: JSONReference,
                       with proc: (inout JSON) throws -> Void) throws
  
  // Mutates the JSON value the reference `ref` is referring to with function
  // `arrProc` if the value is an array or `objProc` if the value is an object. For
  // all other cases, an error is thrown. This method allows for efficient in place
  // mutations without automatically doing any copying. `ref` can be implemented by
  // any abstraction implementing the `JSONReference` procotol.
  mutating func mutate(_ ref: JSONReference,
                       array arrProc: ((inout [JSON]) throws -> Void)? = nil,
                       object objProc: ((inout [String : JSON]) throws -> Void)? = nil,
                       other proc: ((inout JSON) throws -> Void)? = nil) throws
  
  // Mutates the JSON value the reference string `ref` is referring to with function
  // `proc`. `proc` receives a reference to the JSON value, allowing efficient in
  // place mutations without automatically doing any copying. `ref` is a string
  // representation of either `JSONLocation` or `JSONPointer` references.
  mutating func mutate(_ ref: String, with proc: (inout JSON) throws -> Void) throws
  
  // Mutates the JSON array the reference string `ref` is referring to with function
  // `arrProc` if the value is an array or `objProc` if the value is an object. For
  // all other cases, an error is thrown. This method allows for efficient in place
  // mutations without automatically doing any copying. `ref` is a string
  // representation of either `JSONLocation` or `JSONPointer` references.
  mutating func mutate(_ ref: String,
                       array arrProc: ((inout [JSON]) throws -> Void)? = nil,
                       object objProc: ((inout [String : JSON]) throws -> Void)? = nil,
                       other proc: ((inout JSON) throws -> Void)? = nil) throws
  ...
}
```

The most generic form of mutation is provided by the following two methods:

```swift
mutating func mutate(_ ref: JSONReference,
                     with proc: (inout JSON) throws -> Void) throws
mutating func mutate(_ ref: JSONReference,
                     array arrProc: ((inout [JSON]) throws -> Void)? = nil,
                     object objProc: ((inout [String : JSON]) throws -> Void)? = nil,
                     other proc: ((inout JSON) throws -> Void)? = nil) throws
```

These methods mutate the JSON value at which the reference `ref` is referring to via function `proc`.
`proc` receives a reference to this JSON value, allowing efficient, in place mutations without
automatically creating copies.

The second form of the `mutate` method provides specific functions `arrProc` for mutating arrays
and `objProc` for mutating objects, again in a way in which no copies are created. For all
other values, `proc` is being called.

### JSON Patch

_JSON Patch_ defines a JSON document structure for expressing a sequence of operations
to apply to a JSON document. Each operation mutates parts of the JSON document. The supported
operations specified by [RFC 6902](https://datatracker.ietf.org/doc/html/rfc6902/) are
implemented by enum
[`JSONPatchOperation`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSONPatch/JSONPatchOperation.swift):

```swift
enum JSONPatchOperation: Codable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
  // add(path, value): Add `value` to the JSON value at `path`
  case add(JSONPointer, JSON)
  // remove(path): Remove the value at location `path` in a JSON value.
  case remove(JSONPointer)
  // replace(path, value): Replace the value at location `path` with `value`.
  case replace(JSONPointer, JSON)
  // move(path, from): Move the value at `from` to `path`. This is equivalent
  // to first removing the value at `from` and then adding it to `path`.
  case move(JSONPointer, JSONPointer)
  // copy(path, from): Copy the value at `from` to `path`. This is equivalent
  // to looking up the value at `from` and then adding it to `path`.
  case copy(JSONPointer, JSONPointer)
  // test(path, value): Compares value at `path` with `value` and fails if the
  // two are different.
  case test(JSONPointer, JSON)
  ...
}
```

Struct [`JSONPatch`](https://github.com/objecthub/swift-dynamicjson/blob/main/Sources/DynamicJSON/JSONPatch/JSONPatch.swift)
bundles operations together into a "patch object" providing functionality to apply the patch to JSON values:

```swift
struct JSONPatch: Codable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
  // Sequence of operations.
  let operations: [JSONPatchOperation]
  // Initializer based on a sequence of operations
  init(operations: [JSONPatchOperation]) { ... }
  // Decodes the provided data with the given decoding strategies.
  init(data: Data,
       dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
       floatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw,
       userInfo: [CodingUserInfoKey : Any]? = nil) throws { ... }
  // Decodes the provided string with the given decoding strategies.
  init(string: String,
       dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
       floatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw,
       userInfo: [CodingUserInfoKey : Any]? = nil) throws { ... }
  // Decodes the content at the provided URL with the given decoding strategies.
  init(url: URL,
       dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
       floatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw,
       userInfo: [CodingUserInfoKey : Any]? = nil) throws { ... }
  ...
  // Applies this patch object to `json` mutating `json` in place.
  public func apply(to json: inout JSON) throws { ... }
  ...
}
```



### JSON Merge Patch

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
