# Writing Streams of JSON Values

Create NDJSON files, JSON text sequences, JSON arrays, and server-sent events from JSON values.

## Overview

Writing is the counterpart of <doc:StreamingJSON>: the same formats that
``JSON/values(from:format:options:)-7wytv`` reads can be created from JSON values. Everything
that is written can be read again with the matching reading function. The ``JSON/StreamFormat``
for writing has to be chosen explicitly; ``JSON/StreamFormat/automatic`` is only available for
reading.

| Format | What is written |
|--------|-----------------|
| ``JSON/StreamFormat/lines`` | one compact value per line (NDJSON, JSON Lines) |
| ``JSON/StreamFormat/sequence`` | each value preceded by a record separator (0x1E) and followed by a line feed ([RFC 7464](https://datatracker.ietf.org/doc/html/rfc7464/)) |
| ``JSON/StreamFormat/concatenated`` | the values one after the other, separated by ``JSON/StreamWriteOptions/separator`` |
| ``JSON/StreamFormat/arrayElements`` | the values as the elements of one JSON array |
| ``JSON/StreamFormat/serverSentEvents`` | each value as the data of a server-sent event (`text/event-stream`) |

### Writing with a writer

``JSONStreamWriter`` is the building block. It does not do any I/O: each call returns the bytes
that belong to a value, including the framing of the format, and the caller appends them to a
file, a network connection, or a buffer. ``JSONStreamWriter/finish()`` returns the closing bytes
of the stream, for example the `]` of an array.

```swift
var writer = try JSONStreamWriter(format: .lines)
var output = Data()
output.append(try writer.write(["id": 1, "name": "Ada"]))
output.append(try writer.write(["id": 2, "name": "Alan"]))
output.append(try writer.finish())
// {"id":1,"name":"Ada"}
// {"id":2,"name":"Alan"}
```

Values of `Encodable` types can be written directly, without converting them into ``JSON``
values first. A writer reuses one encoder for all values.

### Writing sequences and asynchronous sequences

For a sequence of values that is available in memory, ``JSON/stream(_:format:options:)-3w4rz``
returns the whole stream as `Data`, and ``JSON/write(_:to:format:options:)-alzh`` writes it to a
file.

```swift
let data = try JSON.stream(values, format: .sequence)
try JSON.write(values, to: url, format: .arrayElements,
               options: .init(formatting: [.prettyPrinted, .sortedKeys]))
```

An asynchronous sequence of values is turned into an asynchronous sequence of `Data` chunks by
``JSON/stream(_:format:options:)-9kj5c``, with one chunk for each value and, if the format
needs it, a last chunk that closes the stream. This is what a server needs for a streaming
response, e.g. `Content-Type: application/x-ndjson` or `text/event-stream`:

```swift
for try await chunk in JSON.stream(values, format: .lines) {
  try connection.send(chunk)
}
```

Errors of the sequence of values are passed on, and values that cannot be encoded (floating-point
numbers that are not finite, for example) throw a ``JSON/StreamWriteError``.

### Server-sent events

``ServerSentEvent`` values can be written with names, identifiers, and reconnection times. Data
with several lines becomes several `data` fields, which is why even pretty-printed JSON survives
a transmission. ``JSONStreamWriter/comment(_:)`` writes comments, which servers use as
keep-alive messages, and ``JSON/StreamWriteOptions/terminator`` appends a last event such as
`[DONE]`, which readers of ``JSON/StreamFormat/serverSentEvents`` use as a signal to stop.

```swift
var writer = try JSONStreamWriter(format: .serverSentEvents)
try writer.write(["n": 1], event: "tick", id: "1")
// event: tick
// id: 1
// data: {"n":1}
```

The following function relays the partial values of a model's structured output (see
<doc:StreamingFromAPIs>) as patches, which a client applies to its own copy of the value:

```swift
let events = partials.map { partial in           // partials: PartialJSONStream
  try ServerSentEvent(event: "patch", json: try JSON(encodable: partial.patch(from: nil)))
}
for try await chunk in JSON.stream(events: events) { ... }
```

### Options

``JSON/StreamWriteOptions`` control the encoding: ``JSON/StreamWriteOptions/formatting``
(by default slashes are not escaped; add `.sortedKeys` for output that is the same from run to
run, and `.prettyPrinted` for the formats other than `lines`), strategies for floating-point
numbers and dates, ``JSON/StreamWriteOptions/lineEnding``, the `separator` of concatenated
values, and the SSE `terminator`.

## Topics

### Writing

- ``JSONStreamWriter``
- ``JSON/StreamWriteOptions``
- ``JSON/LineEnding``
- ``JSON/StreamWriteError``

### Streams of values

- ``JSON/stream(_:format:options:)-9kj5c``
- ``JSON/stream(encoding:format:options:)-een4``
- ``JSON/stream(events:options:)``
- ``JSONByteStream``

### Whole sequences, data, and files

- ``JSON/stream(_:format:options:)-3w4rz``
- ``JSON/stream(encoding:format:options:)-7wmkb``
- ``JSON/write(_:to:format:options:)-alzh``
- ``JSON/write(_:to:format:options:)-65o33``

### Server-sent events

- ``ServerSentEvent/encoded``
- ``ServerSentEvent/init(event:json:id:retry:)``
