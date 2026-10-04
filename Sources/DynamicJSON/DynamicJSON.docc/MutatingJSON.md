# Mutating JSON Values

Change JSON values in place or derive modified copies.

## Overview

``JSON`` is a value type. It offers a number of methods that mutate a document in place
without creating copies, as well as non-mutating counterparts that return a modified copy.

### Mutation API

```swift
enum JSON: Hashable, ... {
  // Appends `json` to an array or a string; throws for other kinds of values.
  mutating func append(_ json: JSON) throws

  // Inserts `json` at `index` into an array or a string; throws for other values.
  mutating func insert(_ json: JSON, at index: Int) throws

  // Adds or updates a key/value mapping in a JSON object.
  mutating func assign(_ member: String, to json: JSON) throws

  // Removes a member from a JSON object.
  mutating func remove(_ member: String) throws

  // Replaces the value `ref` is referring to with `json`, in place. `ref` can be any
  // implementation of `JSONReference`, or a string representing a `JSONLocation`
  // or `JSONPointer`.
  mutating func update(_ ref: JSONReference, with json: JSON, insert: Bool = true) throws
  mutating func update(_ ref: String, with json: JSON, insert: Bool = true) throws

  // Mutates the value `ref` is referring to with function `proc`. `proc` receives an
  // `inout` reference, allowing efficient in-place mutations.
  mutating func mutate(_ ref: JSONReference,
                       with proc: (inout JSON) throws -> Void) throws
  mutating func mutate(_ ref: String,
                       with proc: (inout JSON) throws -> Void) throws

  // Mutates the array or object `ref` is referring to with `arrProc` or `objProc`;
  // `proc` handles all other kinds of values.
  mutating func mutate(_ ref: JSONReference,
                       array arrProc: ((inout [JSON]) throws -> Void)? = nil,
                       object objProc: ((inout [String : JSON]) throws -> Void)? = nil,
                       other proc: ((inout JSON) throws -> Void)? = nil) throws
  mutating func mutate(_ ref: String,
                       array arrProc: ((inout [JSON]) throws -> Void)? = nil,
                       object objProc: ((inout [String : JSON]) throws -> Void)? = nil,
                       other proc: ((inout JSON) throws -> Void)? = nil) throws
  ...
}
```

The `mutate` methods are the most generic form of mutation. They locate the value the
reference points to and hand an `inout` reference to a closure, so no copies of the
surrounding document are created. The second form provides dedicated closures for arrays and
objects; `proc` is called for all other kinds of values.

```swift
var json: JSON = ["store": ["book": [1, 2, 3]]]
try json.mutate("/store/book", array: { $0.append(4) })
try json.update("$.store.name", with: "Books")   // inserts a new object member
```

When a copy is preferable to in-place mutation, use ``JSON/updating(_:with:)-(JSONReference,_)``
and ``JSON/applying(patch:)``.

## Topics

### Mutating in place

- ``JSON/append(_:)``
- ``JSON/insert(_:at:)``
- ``JSON/assign(_:to:)``
- ``JSON/remove(_:)``
- ``JSON/update(_:with:insert:)-(JSONReference,_,_)``
- ``JSON/update(_:with:insert:)-(String,_,_)``
- ``JSON/mutate(_:with:insert:)-(JSONReference,_,_)``
- ``JSON/mutate(_:array:object:other:insert:)-(JSONReference,_,_,_,_)``

### Deriving modified copies

- ``JSON/updating(_:with:)-(JSONReference,_)``
- ``JSON/updating(_:with:)-(String,_)``
