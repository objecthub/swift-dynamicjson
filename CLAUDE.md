# DynamicJSON Development Standards for Claude Code

Guidance for working in this repository.

## Overview

_DynamicJSON_ is a Swift framework for representing, querying, mutating, merging, and
validating generic JSON values. It has no third-party dependencies and implements:

| Standard | Entry point |
|----------|-------------|
| JSON (RFC 8259) | `enum JSON` |
| JSON Pointer (RFC 6901) | `struct JSONPointer` |
| JSON Path (RFC 9535) | `enum JSONPath`, `JSONPathParser`, `JSONPathEvaluator` |
| JSON Patch (RFC 6902) | `struct JSONPatch`, `enum JSONPatchOperation`, `JSONPatchMaker` |
| JSON Merge Patch (RFC 7396) | `JSON.merging(patch:)` |
| JSON Schema 2020-12 | `JSONSchema*` types, driven by `JSONSchemaRegistry` |

The public documentation lives in `README.md` (long-form guide) and the DocC catalog at
`Sources/DynamicJSON/DynamicJSON.docc`. Release notes are in `CHANGELOG`.

## Build, test, and docs

```bash
swift build                       # build library and JSONPathTool
swift test                        # run all tests (incl. compliance suites)
swift test --filter JSONPathTests # run one test class
swift run JSONPathTool            # interactive JSON Path REPL against a sample document
```

The project also has an Xcode project (`DynamicJSON.xcodeproj`, schemes `DynamicJSON` and
`JSONPathTool`). Build the DocC archive with:

```bash
xcodebuild docbuild -scheme DynamicJSON -destination 'generic/platform=macOS'
```

The DocC build is expected to be free of warnings; unresolved symbol links show up there. Where
overloads share a name, disambiguate links by parameter types, e.g.
``` ``JSON/query(_:)-(JSONPath)`` ```.

Platforms: macOS 13, iOS 16, tvOS 16, watchOS 9. Package uses `swift-tools-version:5.7` with
Swift language mode 5; README states Xcode 16 / Swift 6 as the toolchain requirement.

## Repository layout

```
Sources/DynamicJSON/
  JSON.swift             Core enum: literals, Codable, accessors, queries, merging,
                         mutation, patching, and schema-validation convenience methods
  JSONType.swift         OptionSet of JSON types (also used as the schema `type` keyword)
  JSONReference.swift    Protocols JSONReference / SegmentableJSONReference / segments
  JSONLocation.swift     Reference = singular JSON Path (`$.a[0]`), the default reference
  JSONPointer.swift      RFC 6901 reference
  LocatedJSON.swift      A JSON value paired with its JSONLocation (query results)
  JSONPath/              Parser → JSONPath AST → JSONPathEvaluator (+ JSONPathEnvironment
                         holding variables and filter functions)
  JSONPatch/             JSONPatch, JSONPatchOperation, JSONPatchMaker (diff)
  JSONSchema/            Schema model, registry, resources, providers, dialects, validators
  Util/                  Indirect, Encodable/Decodable/Array extensions, NSNumber bool check
  DynamicJSON.docc/      DocC catalog (landing page + articles)
Sources/JSONPathTool/    Small command-line REPL for trying out JSON Path queries
Tests/DynamicJSONTests/  XCTest unit tests and compliance suites (see below)
```

## Architecture notes

**`JSON` is the hub.** It is a `@dynamicMemberLookup` indirect value-type enum with seven
cases (`null`, `boolean`, `integer(Int64)`, `float(Double)`, `string`, `array`, `object`).
Integers and floats are separate cases; `JSONType.number` covers both, `JSONType.integer` only
integers. Most feature areas surface as methods on `JSON` that delegate to a dedicated type
(e.g. `query(_:)` → `JSONPathEvaluator`, `apply(patch:)` → `JSONPatch`, `validate(with:)` →
`JSONSchemaRegistry`).

**References.** `JSONReference` (get / set / mutate on a `JSON` value) is implemented by
`JSONLocation` and `JSONPointer`; segmentable references add `segments`, `select(...)` and
`deselect`. `JSON.reference(from:)` picks the implementation from a string (empty or `/…` is a
pointer; everything else is a location, with a leading `$` optional). Mutation goes through `mutate(_:with:insert:)` so that edits
are in place via `inout` and avoid copying the document. Pointer ↔ location conversion is
partial (`JSONLocation.pointer` is optional, `JSONPointer.locations()` returns all candidates)
because pointers cannot tell array indices from numeric member names.

**JSON Path pipeline.** `JSONPathParser` produces a `JSONPath` (indirect enum; segments,
selectors, filter `Expression`s). `JSONPathEvaluator` runs it against a root `JSON` using a
`JSONPathEnvironment`; the standard functions (`length`, `count`, `match`, `search`, `value`,
…) are registered in `JSONPathEnvironment.initialize()`, which is `open` so subclasses add
functions. Results are `[LocatedJSON]`, with `.values` / `.locations` helpers in `Util`.

**JSON Patch.** `JSONPatchOperation` holds one RFC 6902 operation and applies itself;
`JSONPatch` is the ordered list. `JSON.patch(to:)` uses `JSONPatchMaker` (a subclassable,
unoptimized structural diff) to build a patch.

**JSON Schema.**
- `JSONSchema` is the decoded schema; `JSONSchemaResource` wraps a top-level schema, assigns
  identity (`JSONSchemaIdentifier`), and indexes nested resources/anchors.
- `JSONSchemaRegistry` owns dialects, resources, and `JSONSchemaProvider`s (file-based
  discovery). `JSONSchemaRegistry.default` is a shared global instance.
- `JSONSchemaDialect` (a URI plus a validator factory) → `JSONSchemaValidator`. The only
  bundled dialect is `JSONSchemaDraft2020` (an `open` class), whose vocabulary-specific
  methods (`validateCore`, `validateApplicator`, …) can be overridden. `draft2020Format`
  turns `format` into an assertion; `JSONSchemaFormatValidators` hosts the checks.
- `JSONSchemaValidationContext` carries the registry and dynamic scope during validation.
  `JSONSchemaValidationResult` accumulates errors plus annotations (format constraints, meta
  tags, defaults). `defaultPatch` turns missing defaults into a `JSONPatch`.

**Errors.** Each subsystem has its own nested `Error` enum (`JSON.Error`,
`JSONPatchOperation.Error`, `JSONPathEvaluator.Error`, …) conforming to `LocalizedError` and
`CustomStringConvertible`, with `description`, `errorDescription`, and `failureReason`.

## Testing

Tests are XCTest-based. Besides focused unit tests (`JSONConstructorTests`,
`JSONLocationTests`, `JSONPointerTests`, `JSONPathTests`, `JSONMergingTests`,
`JSONMutationTests`, `JSONTypeTests`, `JSONSchemaExampleTest`, …), the suite runs official
**compliance corpora** stored as JSON under `Tests/DynamicJSONTests/ComplianceTests/`:

- `JSONPath/` — the JSONPath compliance test suite (see `LICENSE.txt`/`NOTICE.txt`)
- `JSONPatch/` — the JSON Patch test suite
- `JSONSchema/` — the JSON-Schema-Test-Suite for 2020-12 (`tests/`, `remotes/`, metaschemas)

Each corpus has a `*TestCase` base class that loads a file and executes its cases, and a
`*ComplianceSuite` subclass with one `func testXyz() { self.execute(suite: "xyz") }` per file.
To cover a new corpus file, add a method to the suite **and** list the file under `exclude:`
of the test target in `Package.swift` (otherwise SwiftPM warns about unhandled resources).
Do not edit the vendored corpus files.

## Coding style

The code base follows a style consistently. Match it in new code.

**Layout**
- Two-space indentation, no tabs. Lines are kept to at most 100 columns.
- `case` labels are indented one level inside their `switch`:
  ```swift
  switch self {
    case .null:
      return "null"
    default:
      return "other"
  }
  ```
- Blank lines inside a type or function body carry the surrounding indentation (two spaces
  for members of a top-level type); blank lines at file scope are empty. Keep this when
  editing so diffs stay small.
- Opening braces stay on the same line; long inheritance lists and parameter lists wrap with
  continuation lines aligned under the first item:
  ```swift
  public func valid(for schema: JSONSchema,
                    dialect: JSONSchemaDialect? = nil,
                    using registry: JSONSchemaRegistry? = nil) -> Bool {
  ```
- Group members with `// MARK: - Section name` comments (e.g. `// MARK: - Initializers`).
- if-then-else statements have their then-parts and else-parts always on new lines (i.e.
  if-statements always occupy multiple lines). The same applies to guard-statements.

**File header and structure**
- Every file starts with the standard header (`//  File.swift`, `//  DynamicJSON`,
  `//  Created by Matthias Zenger on dd/MM/yyyy.`, copyright line, Apache 2.0 license block),
  then a blank line, then `import Foundation` (and `import DynamicJSON` outside the module).
  Test files use a shorter header without the license text.
- One primary type per file, named after the file. Extensions for protocol conformances and
  helpers follow the type. Small helper types and errors are nested (`JSON.Error`,
  `JSONPointer.ReferenceToken`, `JSONSchemaValidationResult.Annotation`).

**Naming and idiom**
- Always write `self.` for member access inside methods, properties, and closures
  (`self.value`, `self.select(index:)`).
- Types are `UpperCamelCase` with a `JSON` prefix for framework types; enum cases and members
  are `lowerCamelCase`. Argument labels read like English (`merging(value:)`,
  `overriding(with:)`, `update(_:with:)`, `validator(for:dialect:)`).
- Mutating vs. non-mutating API pairs use the Swift convention: `update` / `updating`,
  `apply(patch:)` / `applying(patch:)`.
- Pattern-match associated values with `case .array(let arr)`; use `.case(_)` for
  ignored payloads in exhaustive switches.
- Prefer `guard … else { return nil }` for early exits and failable projections.
- Failable lookups return optionals; operations that can fail meaningfully `throw` one of the
  subsystem `Error` enums rather than trapping.
- Prefer value types (`struct`/`enum`). Use `class` only for identity or open extension points
  (`JSONPathEnvironment`, `JSONPatchMaker`, `JSONSchemaRegistry`, `JSONSchemaResource`,
  `JSONSchemaDraft2020`); mark those `open` and the rest `public` deliberately. Public types
  are `Sendable` where possible.
- Prefer extending existing protocols/types over adding global functions. Keep everything
  Foundation-only (no new dependencies).

**Documentation comments**
- Every public declaration has a `///` comment written in full sentences in the third person
  ("Returns …", "Creates …", "Mutates …"), referring to parameters with backticks
  (`` `json` ``) rather than `- Parameter:` lists.
- Type-level documentation uses a block with bare `///` lines before and after the text:
  ```swift
  ///
  /// Enum `JSON` encodes JSON documents using seven different cases …
  ///
  public enum JSON { … }
  ```
- Implementation comments (`//`) are sparse and explain _why_, not _what_.

**Tests**
- Test classes are `final class …Tests: XCTestCase`, methods `testSomething() throws`, with
  JSON fixtures written as multi-line string literals passed to `JSON(string:)`, and
  `XCTAssertEqual` on `JSON` values.

## Documentation upkeep

When public API changes:
1. Update the `///` comments on the declaration.
2. Update the relevant DocC article in `Sources/DynamicJSON/DynamicJSON.docc` (and the matching
   section of `README.md`, which the articles mirror) and list new symbols under `## Topics`.
3. Add a line to `CHANGELOG` under the upcoming version.
4. Rebuild the docs (see above) and make sure no new warnings appear.
