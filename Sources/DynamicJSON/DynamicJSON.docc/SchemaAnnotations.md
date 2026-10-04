# Metadata and Defaults

Access format constraints, property metadata, and default values collected during
validation.

## Overview

Besides errors, a ``JSONSchemaValidationResult`` collects annotations produced by schema
keywords while an instance is validated.

### Format annotations

`format` annotations, i.e. declarations that string values have a particular format, are
collected in ``JSONSchemaValidationResult/formatConstraints``. Each constraint is an
``JSONSchemaValidationResult/Annotation`` of ``JSONSchemaValidationResult/FormatConstraint``
that provides the fields `value` (a ``LocatedJSON``), `location` (within the schema),
`message.format` and `message.valid`. `message.valid` is a `Bool?`: `true` for valid
constraints, `false` for invalid constraints, and `nil` for constraints that could not be
validated. This code prints all invalid constraints:

```swift
let res: JSONSchemaValidationResult = ...
for constraint in res.formatConstraints where constraint.message.valid == false {
  print("value \(constraint.value) does not match format '\(constraint.message.format)'")
}
```

By default, invalid format constraints do not cause validation errors. To make them do so, the
vocabulary `https://json-schema.org/draft/2020-12/meta/format-annotation` needs to be
enabled. This is done by creating a custom ``JSONSchemaDraft2020/Dialect`` with a
``JSONSchemaDraft2020/Vocabulary`` whose `formatValid` property is true. Since this is
needed frequently, the preconfigured dialect ``JSONSchemaDialect/draft2020Format`` is
available. A registry with this dialect as its default always validates format annotations.
The built-in format checks are listed in ``JSONSchemaFormatValidators``.

### Default annotations

`default` annotations, i.e. declarations that properties have a given value if they are not
defined explicitly, are collected in ``JSONSchemaValidationResult/defaults``. This property
maps ``JSONLocation`` values to tuples `(exists: Bool, values: Set<JSON>)`. `exists` states
whether a value exists at the location (if so, no default needs to be injected). `values`
contains all suitable defaults, since a schema can define multiple alternatives.

``JSONSchemaValidationResult/nonexistingDefaults`` restricts the defaults to locations without
a value, and ``JSONSchemaValidationResult/defaultPatch`` turns them into a ``JSONPatch`` that
adds a default value (an arbitrary one, if there are several) for each missing location.

```swift
let schema = try JSONSchema(string: #"""
  {
    "$id": "https://objecthub.com/example/person",
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "title": "person",
    "type": "object",
    "properties": {
      "name": {
        "type": "string",
        "minLength": 1
      },
      "birthday": {
        "type": "string",
        "format": "date"
      },
      "numChildren": {
        "type": "integer",
        "default": 0
      },
      "address": {
        "oneOf": [
          { "type": "string", "default": "12345 Mcity" },
          { "$ref": "#address",
            "default": { "city": "Mcity", "postalCode": "12345" } }
        ]
      },
      "email": {
        "type": "array",
        "maxItems": 3,
        "items": {
          "type": "string",
          "format": "email"
        }
      }
    },
    "required": ["name", "birthday"],
    "$defs": {
      "address": {
        "$anchor": "address",
        "type": "object",
        "properties": {
          "street": { "type": "string" },
          "city": { "type": "string" },
          "postalCode": { "type": "string", "pattern": "\\d{5}" }
        },
        "required": ["city", "postalCode"]
      }
    }
  }
"""#)
/// `instance0` is a valid instance of `schema`
let instance0: JSON = [
  "name": "John Doe",
  "birthday": "1983-03-19",
  "numChildren": 2,
  "email": ["john@doe.com", "john.doe@gmail.com"]
]
instance0.valid(for: schema) ⇒ true
/// `instance1` is not a valid instance of `schema`
let instance1: JSON = [
  "name": "John Doe",
  "email": ["john@doe.com", "john.doe@gmail.com"]
]
instance1.valid(for: schema) ⇒ false
/// `instance2` is a valid instance of `schema`
let instance2: JSON = [
  "name": "John Doe",
  "birthday": "1983-03-19",
  "address": "12 Main Street, 17445 Noname"
]
let res2 = try instance2.validate(with: schema)
res2.isValid ⇒ true
for (location, (exists, values)) in res2.defaults {
  if exists {
    print("\(location) exists; defaults: \(values)")
  } else {
    print("\(location) does not exist; defaults: \(values)")
  }
}
```

The loop at the end prints:

```
$['numChildren'] does not exist; defaults: [0]
$['address'] exists; defaults: [
  "12345 Mcity",
  {
    "postalCode" : "12345",
    "city" : "Mcity"
  }
]
```

### Property metadata

Metadata annotations such as `deprecated`, `readOnly`, and `writeOnly` are collected in
``JSONSchemaValidationResult/tags``. Each location within the validated value that carries
such an annotation has an entry of type ``JSONSchemaValidationResult/Annotation`` with
``JSONSchemaValidationResult/MetaTags`` as message, giving access to `value` (a
``LocatedJSON``), `location` (within the schema), and the option set members
`message.deprecated`, `message.readOnly`, and `message.writeOnly`.

## Topics

### Annotations

- ``JSONSchemaValidationResult/Annotation``
- ``JSONSchemaValidationResult/FormatConstraint``
- ``JSONSchemaValidationResult/MetaTags``
- ``JSONSchemaValidationResult/ValidationError``
- ``AnnotationMessage``
- ``FailureReason``

### Collected results

- ``JSONSchemaValidationResult/errors``
- ``JSONSchemaValidationResult/formatConstraints``
- ``JSONSchemaValidationResult/tags``
- ``JSONSchemaValidationResult/defaults``
- ``JSONSchemaValidationResult/nonexistingDefaults``
- ``JSONSchemaValidationResult/defaultPatch``

### Enabling format validation

- ``JSONSchemaDialect/draft2020Format``
- ``JSONSchemaDraft2020/Dialect``
- ``JSONSchemaDraft2020/Vocabulary``
