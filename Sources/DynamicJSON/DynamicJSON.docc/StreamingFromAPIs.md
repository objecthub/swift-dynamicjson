# Streaming JSON from Web APIs and LLMs

Process server-sent events and JSON values that arrive in fragments, such as the output of
large language models.

## Overview

Streaming web APIs, in particular those of large language models, deliver JSON in two layers:

1. The response body is a stream of _server-sent events_ (`text/event-stream`). Each event
   carries a small JSON object, a _delta_.
2. The deltas of a streamed answer often contain _fragments of one larger JSON value_, for
   example the arguments of a tool call or a structured output. No single fragment is valid
   JSON, but applications want to use the partial result as soon as it becomes available.

_DynamicJSON_ supports both layers, which can be combined.

### Server-sent events

Use ``JSON/StreamFormat/serverSentEvents`` to read the JSON data of events. Comments, events
without data and the fields `event`, `id` and `retry` are skipped. If the data of an event
equals ``JSON/StreamOptions/terminator`` (by default `[DONE]`), the stream ends.

```swift
let (bytes, _) = try await URLSession.shared.bytes(for: request)
for try await delta in JSON.values(from: bytes, format: .serverSentEvents) {
  print(delta.choices?[0]?.delta?.content?.stringValue ?? "")
}
```

If the names of events matter, which is the case for APIs that distinguish event types by the
`event` field, use ``JSON/events(from:)-9gody`` to get ``ServerSentEvent`` values:

```swift
for try await event in JSON.events(from: bytes) {
  if event.event == "content_block_delta" {
    print(try event.json())
  }
}
```

### Partial JSON values

``JSONPartialParser`` reads a single JSON value that arrives in fragments and returns the best
available approximation of the value at any time:

```swift
var parser = JSONPartialParser()
try parser.append(#"{"city": "Par"#)
try parser.snapshot()                      // {"city": "Par"}
try parser.append(#"is", "population": 21"#)
try parser.snapshot()                      // {"city": "Paris"}
try parser.append("00000}")
try parser.finish()                        // {"city": "Paris", "population": 2100000}
```

A snapshot closes open strings, arrays, and objects. It leaves out object members whose key or
value is incomplete (except for strings, which are shown in their partial form) and numbers
which might still get more digits. As a consequence, every snapshot is a prefix of all later
snapshots: objects only gain members, arrays only gain elements, and strings only get longer.
The parser validates its input as it arrives and throws a ``JSON/StreamError`` as soon as it
cannot be extended to valid JSON.

The asynchronous variant ``JSON/partialValues(from:)-2rdtf`` takes a sequence of fragments (strings,
data, or bytes) and returns a sequence of ``PartialJSON`` snapshots. The last snapshot is the
complete value. ``PartialJSON/patch(from:)`` computes a ``JSONPatch`` between two successive
snapshots, which allows clients to apply only the changes to a data model or user interface.

### Output that is not pure JSON

Models often surround JSON with prose and Markdown, or produce JSON with small errors.
<doc:ExtractingJSON> describes how to find and parse such JSON leniently.

### Putting it together

``JSON/fragments(from:at:)`` extracts the text fragments from the deltas using a
``JSONPointer``. The example below reads the streamed arguments of a tool call using an
OpenAI-style API; the same code works for Anthropic-style APIs with pointer
`/delta/partial_json`.

```swift
let events = JSON.values(from: bytes, format: .serverSentEvents)
let pointer = try JSONPointer("/choices/0/delta/tool_calls/0/function/arguments")
let fragments = JSON.fragments(from: events, at: pointer)
for try await partial in JSON.partialValues(from: fragments) {
  print(partial.value, partial.isComplete ? "(complete)" : "")
}
```

The library does not contain provider-specific code. Event layouts differ between providers
and change over time; selecting the fragments with a JSON pointer keeps the code independent
of them.

## Topics

### Server-sent events

- ``JSON/events(from:)-9gody``
- ``JSON/events(from:)-4a8d3``
- ``ServerSentEvent``
- ``ServerSentEventStream``
- ``JSON/StreamFormat/serverSentEvents``
- ``JSON/StreamOptions/terminator``

### Partial JSON values

- ``JSONPartialParser``
- ``PartialJSON``
- ``PartialJSONStream``
- ``JSON/partialValues(from:)-2rdtf``
- ``JSON/partialValues(from:)-6o2ml``
- ``JSON/partialValues(from:)-dhl7``

### Extracting fragments

- ``JSON/fragments(from:at:)``
- ``JSONFragmentStream``
