# Queries with JSON Path

Select and extract values from a JSON document with JSON Path queries, and extend the query
language with custom functions.

## Overview

_DynamicJSON_ supports the full _JSON Path_ standard as defined by
[RFC 9535](https://datatracker.ietf.org/doc/html/rfc9535/). The enumeration ``JSONPath``
represents queries, and ``JSON`` provides `query` methods to apply a query to a value.

The examples below use the following document (taken from RFC 9535):

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

### Running a query

A query such as `$.store.book[?@.price < 10].title` is parsed with
``JSONPath/init(query:strict:)`` and applied with ``JSON/query(_:)-(JSONPath)``. The result is an
array of ``LocatedJSON`` values, each combining a matching value with the
``JSONLocation`` where it was found.

```swift
let path = try JSONPath(query: "$.store.book[?@.price < 10].title")
let results = try jval.query(path)
for result in results {
  print(result)
}
```

This prints:

```
$['store']['book'][0]['title'] => "Sayings of the Century"
$['store']['book'][2]['title'] => "Moby Dick"
```

If only values or only locations are needed, use ``JSON/query(values:)-(JSONPath)`` or
``JSON/query(locations:)-(JSONPath)``. All query methods are also available with a query string
instead of a ``JSONPath`` value.

```swift
let titles = try jval.query(values: "$.store.book[?@.price < 10].title")
```

By default, queries are parsed in _strict_ mode, which follows RFC 9535 closely. Pass
`strict: false` to ``JSONPath/init(query:strict:)`` to relax the parser.

### Custom functions

JSON Path has a built-in extensibility mechanism for functions used in filter expressions.
The standard functions `length`, `count`, `match`, `search`, and `value` are provided by
the default ``JSONPathEnvironment``. To add custom functions or variables, subclass
``JSONPathEnvironment`` and override ``JSONPathEnvironment/initialize()``. Register
functions as ``JSONPathEvaluator/Function`` values describing argument types, the result
type, and an implementation:

```swift
class MyEnvironment: JSONPathEnvironment {
  override func initialize() {
    super.initialize()
    self.functions["double"] = JSONPathEvaluator.Function(
      argtypes: [.jsonType],
      restype: .jsonType,
      impl: { root, current, args throws in
        guard case .json(.some(let json)) = args[0], let num = json.doubleValue else {
          return .json(nil)
        }
        return .json(.float(num * 2))
      })
  }
}
```

The extended environment is passed to ``JSONPathEvaluator/init(value:env:strict:)``, which
executes queries against a given document using that environment:

```swift
let evaluator = JSONPathEvaluator(value: jval, env: MyEnvironment())
let results = try evaluator.query(try JSONPath(query: "$.store.book[?double(@.price) > 20]"))
```

## Topics

### Queries

- ``JSONPath``
- ``JSONPathParser``
- ``LocatedJSON``

### Running queries

- ``JSON/query(_:)-(JSONPath)``
- ``JSON/query(values:)-(JSONPath)``
- ``JSON/query(locations:)-(JSONPath)``
- ``JSONPathEvaluator``

### Extending JSON Path

- ``JSONPathEnvironment``
- ``JSONPathEvaluator/Function``
- ``JSONPathEvaluator/Value``
- ``JSONPathEvaluator/ValueType``
