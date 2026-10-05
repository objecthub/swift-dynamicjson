# Extracting JSON from LLM Output

Find JSON values in text produced by large language models, and parse JSON that is not
quite valid.

## Overview

Language models are good at producing JSON, but they rarely produce _only_ JSON. A typical
answer wraps the data in an introduction and a Markdown code block, and the JSON itself often
deviates from the standard: it might contain comments or trailing commas, use single quotes
or Python's `None`, or be cut off because the model hit its length limit. A strict parser
such as ``JSON/init(string:dateDecodingStrategy:floatDecodingStrategy:userInfo:)`` rejects all
of this.

_DynamicJSON_ provides a lenient parser and an extraction function for this situation. They are
independent of the strict parser, which remains RFC 8259 conformant.

### Finding values in text

``JSON/extract(from:options:)`` searches a text for Markdown code blocks and for JSON objects
and arrays in running text, and returns the values it finds in the order in which they appear:

```swift
let answer = """
  Sure! Here is the data you asked for:

  ```json
  {
    "name": "Ada",           // the first programmer
    "languages": ["en", "fr",],
  }
  ```

  Let me know if you need anything else.
  """

for found in JSON.extract(from: answer) {
  print(found.value)
  print(found.source)    // fencedBlock(language: Optional("json"))
  print(found.repairs)   // [comment, trailingComma]
  print(answer[found.range])
}
```

Each result is an ``ExtractedJSON`` value. Besides the parsed ``ExtractedJSON/value``, it tells
where the value was found (``ExtractedJSON/source``), the ``ExtractedJSON/range`` it occupies in
the text, and the ``JSONRepair`` deviations from JSON that had to be accepted
(``ExtractedJSON/repairs``). If ``ExtractedJSON/isStrict`` is true, the source text of the
value is valid JSON. Use ``JSON/extractFirst(from:options:)`` if only the first value matters.

The search is controlled by ``JSONExtractionOptions``:

- ``JSONExtractionOptions/scope`` restricts the search to the content of code blocks.
- ``JSONExtractionOptions/types`` selects the kinds of values to extract. The default is objects
  and arrays. Use `[.object]` if the text might contain arrays that are not data, such as
  footnote markers like `[1]`.
- ``JSONExtractionOptions/repairTruncation`` enables the repair of truncated values (the
  default).
- ``JSONExtractionOptions/maxCount`` limits the number of results.

In running text, a candidate is accepted if the lenient parser can read a complete value
starting at an opening brace or bracket. Text such as `{ not json }` is skipped. If a candidate
fails, the search continues inside of it, so a valid object within a malformed one is found.

### Parsing one value leniently

If a text is known to consist of one value, ``JSON/init(lenient:repairTruncation:)`` parses it.
Whitespace around the value and a Markdown code block that encloses it are ignored. The
initializer throws a ``JSON/LenientError`` if the text is not a value.

```swift
let json = try JSON(lenient: "{name: 'Ada', age: 36, nickname: None,}")
// {"name": "Ada", "age": 36, "nickname": null}
```

### What is accepted

Every deviation that is accepted is one of the cases of ``JSONRepair``:

| Repair | Example |
|--------|---------|
| ``JSONRepair/comment`` | `// note`, `/* note */` |
| ``JSONRepair/trailingComma`` | `[1, 2,]` |
| ``JSONRepair/missingComma`` | `{"a": 1 "b": 2}` |
| ``JSONRepair/singleQuotedString`` | `'text'` |
| ``JSONRepair/unquotedKey`` | `{name: "x"}` |
| ``JSONRepair/nonStandardLiteral`` | `True`, `None`, `nil`, `undefined` (all mapped to JSON values) |
| ``JSONRepair/nonStandardNumber`` | `+1`, `.5`, `5.`, `007`, `0x1F` |
| ``JSONRepair/nonFiniteNumber`` | `NaN`, `Infinity` (replaced by `null`) |
| ``JSONRepair/rawControlCharacter`` | line breaks inside of strings |
| ``JSONRepair/invalidEscape`` | `"a\qb"` (stands for the escaped character) |
| ``JSONRepair/truncated`` | the text ends inside of a value |

A truncated value is completed in the same way as the snapshots of ``JSONPartialParser``:
open strings, arrays, and objects are closed, and members and elements that are incomplete
are dropped. Duplicate keys in an object are resolved in favor of the last one.

### Combining with streaming

The lenient parser works on complete texts. To process the output of a model while it is
being generated, collect the text fragments and call ``JSON/extractFirst(from:options:)``
whenever new text arrives, or use ``JSONPartialParser`` (see <doc:StreamingFromAPIs>) if the
output is known to be pure JSON.

## Topics

### Extracting values

- ``JSON/extract(from:options:)``
- ``JSON/extractFirst(from:options:)``
- ``JSONExtractionOptions``
- ``ExtractedJSON``

### Parsing leniently

- ``JSON/init(lenient:repairTruncation:)``
- ``JSONRepair``
- ``JSON/LenientError``
