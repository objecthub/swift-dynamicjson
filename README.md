# Swift DynamicJSON

[![Platforms: macOS, iOS, Linux](https://img.shields.io/badge/Platforms-macOS,%20iOS,%20Linux-blue.svg?style=flat)](https://developer.apple.com/osx/) [![Language: Swift 5.9](https://img.shields.io/badge/Language-Swift%205.9-green.svg?style=flat)](https://developer.apple.com/swift/) [![IDE: Xcode 15](https://img.shields.io/badge/IDE-Xcode%2015-orange.svg?style=flat)](https://developer.apple.com/xcode/) [![Package managers: SwiftPM, Carthage](https://img.shields.io/badge/Package%20managers-SwiftPM,%20Carthage-8E64B0.svg?style=flat)](https://github.com/Carthage/Carthage) [![License: Apache](http://img.shields.io/badge/License-Apache-lightgrey.svg?style=flat)](https://raw.githubusercontent.com/objecthub/swift-numberkit/master/LICENSE)

_DynamicJSON_ is a framework for representing, querying, and manipulating generic JSON values. The framework provides:

   - A generic representation of JSON values as defined by [RFC 8259](https://datatracker.ietf.org/doc/html/rfc8259/).
   - A natural embedding of functionality for creating and manipulating JSON values into the Swift programming language, including support for reading and writing JSON data and for converting typed and untyped JSON representations.
   - An implementation of _JSON Pointer_ as defined by [RFC 6901](https://datatracker.ietf.org/doc/html/rfc6901/) for locating values within a JSON document.
   - An implementation of _JSON Path_ as defined by [RFC 9535](https://datatracker.ietf.org/doc/html/rfc9535/) for querying JSON data.
   - An implementation of _JSON Patch_ as defined by [RFC 6902](https://datatracker.ietf.org/doc/html/rfc6902/) for mutating JSON data.
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
let json1 = try JSON(encoded: """
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
let person = Person(name: "John",
                    age: 34,
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

## Accessing JSON Values

JSON values can be accessed using dynamic member lookup as if the data was typed.
Here are several examples showcasing the different ways how to access the first
element of array `arr` in `object` of `json1`. All expressions return the JSON
value 1.

   - **Dynamic member lookup:** `json1.object?.arr?[0]`
   - **Keypath lookup:** `json1[keyPath: \.object?.arr?[0]]`
   - **Subscript lookup:** `json1["object"]?["arr"]?[0]`
   - **Reference lookup:**
      - Using JSON Pointer string: `try json1[ref: "/object/arr/0"]`
      - Using JSON Path string: `try json1[ref: "$.object.arr[0]"]`
      - Using `JSONPointer` or `JSONPath` object `p`: `json1[ref: p]`

## Access with JSON Pointer

## Queries with JSON Path

## Mutating JSON Values

## Using JSON Patch

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
