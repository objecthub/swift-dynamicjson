# Validating JSON Data

Validate JSON instances against JSON schemas using registries, dialects, and validators.

## Overview

_DynamicJSON_ implements _JSON Schema_ as defined by the
[2020-12 Internet Draft specification](https://datatracker.ietf.org/doc/draft-bhutton-json-schema/).
The framework is designed to be extensible so that future revisions can be supported.

### Implementation overview

A JSON schema is represented by the enumeration ``JSONSchema``. Schemas can be loaded from a
file, or decoded from a string or a `Data` object. Within schema validation, top-level schemas
are managed by the class ``JSONSchemaResource``, which pre-processes and validates schema
values and gives them an identity. It is often easier to work with ``JSONSchemaResource``
objects directly.

Schemas are identified by ``JSONSchemaIdentifier`` values, which are essentially URIs with
schema-specific methods. An identifier is either absolute or relative, and either a _base_
URI referring to a top-level schema or a non-base URI referring to a schema nested within
another schema via a URI fragment.

The semantics of a schema is defined by its _dialect_, which is identified by a URI that a
schema declares via keyword `$schema`. If no dialect is declared, top-level schemas use the
registry's default dialect (``JSONSchemaDialect/draft2020`` unless configured otherwise), and
nested schemas inherit the dialect of their enclosing schema. Dialects implement the
``JSONSchemaDialect`` protocol, whose key responsibility is a factory method
`validator(for:in:)` creating validator objects. Validators implement
``JSONSchemaValidator``, whose `validate(_:)` method takes a JSON instance and returns a
``JSONSchemaValidationResult``. The bundled implementation of the 2020-12 draft is
``JSONSchemaDraft2020``.

The whole validation process is initiated and controlled by a ``JSONSchemaRegistry``. A
registry defines:

- a set of supported dialects with their URI identities,
- a default dialect for schemas that do not declare one,
- a set of known schema resources with their identities, and
- ``JSONSchemaProvider`` objects that discover and load schema resources that are not loaded
  yet (see ``JSONSchemaFileProvider`` and ``StaticJSONSchemaFileProvider``).

Most of the registry API is about configuring registries: registering dialects, inserting
available schema resources, and setting up providers. Once configured,
``JSONSchemaRegistry/validator(for:dialect:)-(JSONSchemaIdentifier,_)`` returns a ``JSONSchemaValidator`` for a
schema resource, which can be used to validate any number of JSON instances.

```swift
// Create a new schema registry
let registry = JSONSchemaRegistry()
// Register a schema resource from a string literal
try registry.register(resource: JSONSchemaResource(string: #"""
  {
    "$id": "https://example.com/schema/test",
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "properties": {
      "prop1": {
        ...
      }
    }
  }
"""#))
...
// Load a schema resource from a file
try registry.loadSchema(from: URL(filePath: "/Users/objecthub/foo.json"))
...
// Make JSON schema stored in json files under the given directory discoverable
registry.register(provider:
  StaticJSONSchemaFileProvider(
    directory: URL(filePath: "/Users/objecthub/myschema"),
    base: JSONSchemaIdentifier(string: "http://example.com/schemas")!))
...
// Obtain a validator for a schema
guard let validator = try? registry.validator(for: "https://example.com/schema/test") else {
  // Throw error stating that the schema could not be found
}
// Validate a JSON instance `json`
let result = validator.validate(json)
print("valid = \(result.isValid)")
```

Validators return ``JSONSchemaValidationResult`` values. Besides validation errors, a result
collects format constraints, metadata tags, and default values; see <doc:SchemaAnnotations>.
Use ``JSONSchemaValidationResult/isValid`` to find out whether validation succeeded; if it is
`false`, ``JSONSchemaValidationResult/errors`` describes what went wrong.

### Validation API

Applications that validate instances against a small number of fixed schemas do not need
the low-level API above. ``JSON`` provides convenience methods for this case:

```swift
enum JSON: Hashable, ... {
  // Returns true if this JSON document is valid for the given JSON schema (using
  // `registry` for resolving references to schemas referred to from `schema`).
  func valid(for schema: JSONSchema,
             dialect: JSONSchemaDialect? = nil,
             using registry: JSONSchemaRegistry? = nil) -> Bool

  // Returns a schema validation result for this JSON document validated against `schema`.
  func validate(with schema: JSONSchema,
                dialect: JSONSchemaDialect? = nil,
                using registry: JSONSchemaRegistry? = nil) throws -> JSONSchemaValidationResult

  // The same, for schema resources.
  func valid(for resource: JSONSchemaResource,
             dialect: JSONSchemaDialect? = nil,
             using registry: JSONSchemaRegistry? = nil) -> Bool
  func validate(with resource: JSONSchemaResource,
                dialect: JSONSchemaDialect? = nil,
                using registry: JSONSchemaRegistry? = nil) throws -> JSONSchemaValidationResult
  ...
}
```

If `registry` is `nil`, a new registry is created on demand in which only the provided schema
or resource is registered. Schemas that are not self-contained therefore require a suitably
configured registry. Alternatively, ``JSONSchemaRegistry/default`` provides a single, shared,
global registry.

## Topics

### Schemas

- ``JSONSchema``
- ``JSONSchemaResource``
- ``JSONSchemaIdentifier``

### Registries and providers

- ``JSONSchemaRegistry``
- ``DefaultJSONSchemaRegistry``
- ``JSONSchemaProvider``
- ``JSONSchemaFileProvider``
- ``StaticJSONSchemaFileProvider``

### Dialects and validators

- ``JSONSchemaDialect``
- ``JSONSchemaDraft2020``
- ``JSONSchemaValidator``
- ``JSONSchemaValidationContext``
- ``JSONSchemaFormatValidators``

### Results

- ``JSONSchemaValidationResult``

### Validating instances

- ``JSON/valid(for:dialect:using:)-(JSONSchema,_,_)``
- ``JSON/validate(with:dialect:using:)-(JSONSchema,_,_)``
- ``JSON/valid(for:dialect:using:)-(JSONSchemaResource,_,_)``
- ``JSON/validate(with:dialect:using:)-(JSONSchemaResource,_,_)``
