# JSON Patch

Describe changes to a JSON document as a sequence of operations, and compute such a sequence
from two documents.

## Overview

_JSON Patch_ ([RFC 6902](https://datatracker.ietf.org/doc/html/rfc6902/)) defines a JSON
document structure for expressing a sequence of operations that mutate a JSON document. The
operations are represented by the enumeration ``JSONPatchOperation``:

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

The struct ``JSONPatch`` bundles operations into a patch object that can be applied to
JSON values, encoded, and decoded. Patches are created from operations
(``JSONPatch/init(operations:)``), from JSON text
(``JSONPatch/init(string:dateDecodingStrategy:floatDecodingStrategy:userInfo:)``,
``JSONPatch/init(data:dateDecodingStrategy:floatDecodingStrategy:userInfo:)``,
``JSONPatch/init(url:dateDecodingStrategy:floatDecodingStrategy:userInfo:)``), or from a
``JSON`` value (``JSONPatch/init(_:)``).

### Applying a patch

The following code loads a patch from a string and applies it to a JSON value:

```swift
let jsonstr = """
  [
    { "op": "test", "path": "/a/b/c", "value": "foo" },
    { "op": "remove", "path": "/a/b/c" },
    { "op": "add", "path": "/a/b/c", "value": [ "foo", "bar" ] },
    { "op": "replace", "path": "/a/b/c", "value": 42 },
    { "op": "move", "from": "/a/b/c", "path": "/a/b/d" },
    { "op": "copy", "from": "/a/b/d", "path": "/a/b/e" }
  ]
  """
let patch = try JSONPatch(string: jsonstr)
var json: JSON = ...
try json.apply(patch: patch)
```

``JSON/apply(patch:)`` mutates a value in place; ``JSON/applying(patch:)`` returns a modified
copy. ``JSONPatch/apply(to:)`` and ``JSONPatchOperation/apply(to:)`` operate directly on an
`inout` value.

### Computing a patch

Given two JSON values `source` and `target`, `source.patch(to: target)` returns a
``JSONPatch`` that transforms `source` into `target` when applied. The generated patches are
correct but currently not optimized. Subclass ``JSONPatchMaker`` and pass it as the `via`
argument of ``JSONPatch/init(from:to:via:)`` to customize the diffing algorithm.

## Topics

### Patch objects

- ``JSONPatch``
- ``JSONPatchOperation``
- ``JSONPatchMaker``

### Applying patches

- ``JSON/apply(patch:)``
- ``JSON/apply(operation:)``
- ``JSON/applying(patch:)``

### Creating patches

- ``JSON/patch(to:)``
- ``JSONPatch/init(from:to:via:)``
