# Representing JSON Data

Create JSON values from Swift literals, JSON text, and `Codable` types, and convert them
back again.

## Overview

All JSON values in _DynamicJSON_ are represented by the enumeration ``JSON``. It has one
case per kind of JSON value:

```swift
indirect enum JSON: Hashable, Codable, CustomStringConvertible, ... {
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

Integers and floating-point numbers are kept apart: JSON numbers without a fractional part
or exponent that fit into `Int64` are represented as ``JSON/integer(_:)``, all others
as ``JSON/float(_:)``. The type of a value is available via ``JSON/type``; see ``JSONType``.

### Creating JSON values from literals

``JSON`` conforms to all of Swift's `ExpressibleBy...Literal` protocols, so JSON documents
can be written in plain Swift syntax:

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

### Decoding JSON text

Use ``JSON/init(string:dateDecodingStrategy:floatDecodingStrategy:userInfo:)``,
``JSON/init(data:dateDecodingStrategy:floatDecodingStrategy:userInfo:)``, or
``JSON/init(url:dateDecodingStrategy:floatDecodingStrategy:userInfo:)`` to parse JSON-encoded
text:

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

### Converting to and from Swift types

Any `Encodable` value can be turned into a ``JSON`` value with
``JSON/init(encodable:)``. The more generic ``JSON/init(_:)`` additionally coerces basic
Swift values such as `Bool`, `Int`, `String`, arrays, and dictionaries.

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

This prints:

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

The inverse direction is provided by ``JSON/coerce()``, which decodes a generic ``JSON``
value into a strongly typed `Decodable` value:

```swift
let json3: JSON = [
  "name": "Matthew",
  "age": 29,
  "children": []
]
let person2: Person = try json3.coerce()
```

### Encoding JSON values

Use ``JSON/string(formatting:dateEncodingStrategy:floatEncodingStrategy:userInfo:)`` or
``JSON/data(formatting:dateEncodingStrategy:floatEncodingStrategy:userInfo:)`` to serialize
a value. The ``JSON/description`` property provides a pretty-printed representation.

### Convenience accessors

``JSON`` offers failable projections such as ``JSON/boolValue``, ``JSON/intValue``,
``JSON/doubleValue``, ``JSON/stringValue``, ``JSON/arrayValue``, and ``JSON/objectValue``
which return `nil` if the value is of a different kind, as well as
``JSON/arrayElements`` and ``JSON/objectBindings`` which return empty collections instead.
``JSON/children`` and ``JSON/forEachDescendant(_:)`` support traversing a document.

## Topics

### Essentials

- ``JSON``
- ``JSONType``

### Creating JSON values

- ``JSON/init(_:)``
- ``JSON/init(encodable:)``
- ``JSON/init(string:dateDecodingStrategy:floatDecodingStrategy:userInfo:)``
- ``JSON/init(data:dateDecodingStrategy:floatDecodingStrategy:userInfo:)``
- ``JSON/init(url:dateDecodingStrategy:floatDecodingStrategy:userInfo:)``

### Exporting JSON values

- ``JSON/coerce()``
- ``JSON/string(formatting:dateEncodingStrategy:floatEncodingStrategy:userInfo:)``
- ``JSON/data(formatting:dateEncodingStrategy:floatEncodingStrategy:userInfo:)``

### Inspecting JSON values

- ``JSON/type``
- ``JSON/isNull``
- ``JSON/boolValue``
- ``JSON/intValue``
- ``JSON/int64Value``
- ``JSON/doubleValue``
- ``JSON/stringValue``
- ``JSON/arrayValue``
- ``JSON/arrayElements``
- ``JSON/objectValue``
- ``JSON/objectBindings``
- ``JSON/children``
- ``JSON/forEachDescendant(_:)``
