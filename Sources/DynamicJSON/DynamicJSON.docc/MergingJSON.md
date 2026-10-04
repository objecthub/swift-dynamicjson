# Merging JSON Values

Combine JSON documents symmetrically, with overrides, or via JSON Merge Patch.

## Overview

_DynamicJSON_ offers three ways of merging JSON values, each suited for a different purpose.

### Symmetrical merge

The method ``JSON/isRefinement(of:)`` defines a relationship between two JSON values.
`a.isRefinement(of: b)` is true if

1. both `a` and `b` are JSON values of the same type,
2. if `a` and `b` are arrays, they have the same length _n_ and `a[i].isRefinement(of: b[i])`
   holds for every i ∈ [0; _n_[,
3. if `a` and `b` are objects, for every member `m` of `b` with value `b[m]`, there is a
   member `m` of `a` with value `a[m]` such that `a[m].isRefinement(of: b[m])`,
4. for all other types, `a` and `b` are the same, i.e. `a == b`.

Intuitively: whenever it is possible to read a value at a given location from `b`, it is also
possible to read a value at that location from `a`, and the value read from `a` is a
refinement of the value read from `b`.

```swift
let a = try JSON(string: #"""
  {
    "a": [1, { "b": 2 }],
    "c": { "d": [{}] }
  }
"""#)
let b = try JSON(string: #"""
  {
    "a": [1, { "b": 2, "e": 4 }],
    "c": { "d": [{"f": 5}] }
  }
"""#)
b.isRefinement(of: a) ⇒ true
```

``JSON/merging(value:)`` merges two values `a` and `b` into the "smallest" value that is a
refinement of both. If no such value exists, the method returns `nil`.

```swift
let c = try JSON(string: #"""
  { "a": [1, {"e": 8}],
    "c": {"f": "hello"},
    "g": 9 }
"""#)
a.merging(value: c)
⇒
{
  "a": [1, { "b": 2, "e": 8 }],
  "c": { "d": [{}], "f": "hello" },
  "g": 9
}
```

Non-existing values are added to the result and overlapping values are merged where possible.
If two values cannot be merged, the result is `nil`.

### Overriding merge

``JSON/overriding(with:)`` merges two values differently: the argument overrides values of
the receiver wherever a symmetrical merge would fail. Arrays do not need to have the same
length. The result has the length of the longer array, and elements available in both are
combined with `overriding(with:)`.

```swift
let d = try JSON(string: #"""
  {
    "a": [1, { "e": 2 }, 3],
    "c": { "d": "hello" },
    "f": 5
  }
"""#)
a.overriding(with: d)
⇒
{
  "a": [1, { "b": 2, "e": 2 }, 3],
  "c": { "d": "hello" },
  "f": 5
}
```

### JSON Merge Patch

``JSON/merging(patch:)`` implements _JSON Merge Patch_ as defined by
[RFC 7396](https://datatracker.ietf.org/doc/html/rfc7396/). A merge patch document describes
changes to a target document using a syntax that closely mimics the document being modified.
Members of the patch that do not appear in the target are added, members that do appear are
replaced, and `null` values in the patch remove the corresponding members from the target.
Objects are merged recursively; all other kinds of values are replaced by the patch.

```swift
let target = try JSON(string: #"{"a": "b", "c": {"d": "e", "f": "g"}}"#)
let patch = try JSON(string: #"{"a": "z", "c": {"f": null}}"#)
target.merging(patch: patch)
⇒
{"a": "z", "c": {"d": "e"}}
```

The implementation does not mutate the existing value. It constructs a new value by merging
the old one with the patch document.

## Topics

### Merging

- ``JSON/isRefinement(of:)``
- ``JSON/merging(value:)``
- ``JSON/overriding(with:)``
- ``JSON/merging(patch:)``
