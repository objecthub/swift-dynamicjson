# ``DynamicJSON``

Represent, query, mutate, merge, and validate generic JSON values.

## Overview

_DynamicJSON_ is a framework for working with JSON data in Swift without having to define
a strongly typed model first. All JSON values are represented by the enumeration ``JSON``,
which embeds naturally into Swift via literal syntax, dynamic member lookup, and
`Codable` support.

On top of this core representation, the framework implements the following standards:

- **JSON** as defined by [RFC 8259](https://datatracker.ietf.org/doc/html/rfc8259/)
- **JSON Pointer** as defined by [RFC 6901](https://datatracker.ietf.org/doc/html/rfc6901/)
  for locating values within a JSON document (see ``JSONPointer``)
- **JSON Path** as defined by [RFC 9535](https://datatracker.ietf.org/doc/html/rfc9535/)
  for querying JSON data (see ``JSONPath``)
- **JSON Patch** as defined by [RFC 6902](https://datatracker.ietf.org/doc/html/rfc6902/)
  for mutating JSON data (see ``JSONPatch``)
- **JSON Merge Patch** as defined by [RFC 7396](https://datatracker.ietf.org/doc/html/rfc7396/)
  for merging JSON data with patch documents (see ``JSON/merging(patch:)``)
- **JSON streaming**: NDJSON / JSON Lines, JSON text sequences ([RFC 7464](https://datatracker.ietf.org/doc/html/rfc7464/)), concatenated JSON, and incrementally read top-level arrays (see <doc:StreamingJSON>), as well as server-sent events and partial JSON values as delivered by streaming web APIs and large language models (see <doc:StreamingFromAPIs>)
- **JSON Schema** as defined by the
  [2020-12 Internet Draft specification](https://datatracker.ietf.org/doc/draft-bhutton-json-schema/)
  for validating JSON data (see ``JSONSchema``)

Here is a small example showing how these pieces fit together:

```swift
import DynamicJSON

let json: JSON = [
  "name": "Matthew",
  "age": 29,
  "children": [["name": "Sofia", "age": 5]]
]

// Dynamic member lookup
json.children?[0]?.name           // "Sofia"

// JSON Path query
try json.query(values: "$.children[?@.age < 10].name")   // ["Sofia"]

// Update a copy of the document with a JSON pointer
let older = try json.updating("/age", with: 30)
```

### Requirements

The framework requires Xcode 16 and Swift 6 (the package declares Swift language mode 5). It
is available via the Swift Package Manager and Carthage.

## Topics

### Essentials

- <doc:RepresentingJSON>
- <doc:AccessingJSON>
- ``JSON``
- ``JSONType``

### Locating values

- <doc:AccessingJSON>
- ``JSONReference``
- ``SegmentableJSONReference``
- ``JSONReferenceSegment``
- ``JSONReferenceSegmentIndex``
- ``JSONReferenceError``
- ``JSONLocation``
- ``JSONPointer``
- ``LocatedJSON``

### Querying with JSON Path

- <doc:QueryingJSON>
- ``JSONPath``
- ``JSONPathParser``
- ``JSONPathEvaluator``
- ``JSONPathEnvironment``

### Changing JSON values

- <doc:MutatingJSON>
- <doc:PatchingJSON>
- ``JSONPatch``
- ``JSONPatchOperation``
- ``JSONPatchMaker``

### Merging JSON values

- <doc:MergingJSON>

### Streaming JSON values

- <doc:StreamingJSON>
- <doc:StreamingFromAPIs>
- <doc:ExtractingJSON>
- ``JSONValueStream``
- ``JSONResultStream``
- ``JSONResultSequence``
- ``ServerSentEvent``
- ``ServerSentEventStream``
- ``JSONPartialParser``
- ``PartialJSON``
- ``PartialJSONStream``
- ``JSONFragmentStream``
- ``JSONExtractionOptions``
- ``ExtractedJSON``
- ``JSONRepair``

### Validating with JSON Schema

- <doc:ValidatingJSON>
- <doc:SchemaAnnotations>
- ``JSONSchema``
- ``JSONSchemaResource``
- ``JSONSchemaIdentifier``
- ``JSONSchemaRegistry``
- ``DefaultJSONSchemaRegistry``
- ``JSONSchemaProvider``
- ``JSONSchemaFileProvider``
- ``StaticJSONSchemaFileProvider``
- ``JSONSchemaDialect``
- ``JSONSchemaDraft2020``
- ``JSONSchemaValidator``
- ``JSONSchemaValidationContext``
- ``JSONSchemaValidationResult``
- ``JSONSchemaFormatValidators``

### Utilities

- ``Indirect``
