# Streaming JSON Values

Read sequences of JSON values from files, network responses, and pipes, one value at a time.

## Overview

Many sources deliver not a single JSON document, but a _sequence_ of JSON values: log files,
web service responses, exports of databases, or the output of other processes. Reading such
data with ``JSON/init(data:dateDecodingStrategy:floatDecodingStrategy:userInfo:)`` would require
holding everything in memory and does not work if the data is not one valid document.

``JSON/values(from:format:options:)->JSONValueStream<S>`` is the single entry point for reading
sequences of JSON values from an asynchronous sequence of bytes. The format in which values are
delimited is selected by a ``JSON/StreamFormat``:

| Format | Description |
|--------|-------------|
| ``JSON/StreamFormat/lines`` | NDJSON and JSON Lines (`.ndjson`, `.jsonl`): one value per line |
| ``JSON/StreamFormat/sequence`` | JSON text sequences, [RFC 7464](https://datatracker.ietf.org/doc/html/rfc7464/) (`application/json-seq`) and [RFC 8142](https://datatracker.ietf.org/doc/html/rfc8142/) (GeoJSON text sequences): each value is preceded by the ASCII record separator (0x1E) |
| ``JSON/StreamFormat/concatenated`` | values follow each other with arbitrary or no whitespace in between, e.g. `{"a":1}{"b":2}` |
| ``JSON/StreamFormat/arrayElements`` | the elements of one huge top-level array are returned incrementally |
| ``JSON/StreamFormat/serverSentEvents`` | server-sent events (`text/event-stream`), the transport of most streaming web APIs; see <doc:StreamingFromAPIs> |
| ``JSON/StreamFormat/automatic`` | the default: `sequence` if the stream starts with a record separator, `serverSentEvents` if it starts with an event field or a comment, `concatenated` otherwise |

### Reading values asynchronously

Any `AsyncSequence` with element type `UInt8` can be used as a source, e.g. `URL.resourceBytes`,
`FileHandle.bytes`, or `URLSession.bytes(from:)`:

```swift
for try await value in JSON.values(from: url.resourceBytes, format: .lines) {
  print(value.name?.stringValue ?? "?")
}
```

Values are decoded as soon as their last byte has arrived; the stream never holds more than
one value in memory. For files and URLs, there is a shortcut:

```swift
for try await value in JSON.values(contentsOf: url, format: .lines) { ... }
```

### Reading values from memory

For data that is available in memory, `JSON.values(from:)` returns an array of all values, and
``JSON/results(from:format:options:)->JSONResultSequence<S>`` a lazy sequence:

```swift
let values = try JSON.values(from: "{\"a\": 1}\n{\"a\": 2}\n", format: .lines)
let data = try Data(contentsOf: url)
for result in JSON.results(from: data, format: .sequence) { ... }
```

### Handling errors

By default, the first malformed value ends the stream: the `for try await` loop throws a
``JSON/StreamError`` that contains the byte offset at which the problem was found when it
reaches that value, and no further values are read. Two other
options exist:

- With ``JSON/StreamErrorPolicy/skipInvalid`` in ``JSON/StreamOptions``, malformed values are
  dropped and reading continues. This is the behavior recommended by RFC 7464, and it works
  reliably for `lines` and `sequence`, which can resynchronize at the next line or record
  separator. For `concatenated`, the remainder of the stream after a malformed value might not
  be interpreted as intended.
- ``JSON/results(from:format:options:)->JSONResultStream<S>`` returns `Result` values and never
  throws stream errors, so that the caller decides what to do with each failure.

Some errors are fatal (see ``JSON/StreamError/isFatal``) and always end the stream. Errors thrown
by the underlying byte sequence are passed on unchanged.

### Details of the supported formats

**Lines.** Each line holds one value. Lines may end in `\r\n`, blank lines are ignored, and a
UTF-8 byte order mark at the beginning of the stream is skipped. Values must not contain line
breaks; use `concatenated` for pretty-printed values.

**JSON text sequences.** Values may contain line breaks. Repeated record separators do not
create empty values. Following RFC 7464, a top-level number, `true`, `false`, or `null` that is
not followed by whitespace might have been truncated and is dropped.

**Concatenated JSON.** Boundaries are found by tracking brackets and strings; the values are
not parsed twice. Top-level numbers and literals need to be separated by whitespace from the
next value.

**Array elements.** The stream has to consist of exactly one array. Elements are returned
without the array being held in memory. Content after the closing bracket is an error.

### Limiting memory

Set ``JSON/StreamOptions/maxValueSize`` to reject values that exceed a given number of bytes,
for example when reading untrusted input. The resulting error is fatal.

## Topics

### Reading streams

- ``JSON/values(from:format:options:)->JSONValueStream<S>``
- ``JSON/results(from:format:options:)->JSONResultStream<S>``
- ``JSON/values(contentsOf:format:options:)``
- ``JSONValueStream``
- ``JSONResultStream``

### Reading data in memory

- ``JSON/values(from:format:options:)-(S,_,_)->[JSON]``
- ``JSON/values(from:format:options:)-(String,_,_)``
- ``JSON/results(from:format:options:)->JSONResultSequence<S>``
- ``JSONResultSequence``

### Creating streams

- <doc:WritingStreams>

### Streams from web APIs

- <doc:StreamingFromAPIs>

### Configuration

- ``JSON/StreamFormat``
- ``JSON/StreamOptions``
- ``JSON/StreamErrorPolicy``
- ``JSON/StreamError``
