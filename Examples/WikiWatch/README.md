# WikiWatch

A small command-line tool demonstrating the streaming support of _DynamicJSON_ with a real-world
stream: Wikimedia's public [EventStreams](https://wikitech.wikimedia.org/wiki/Event_Platform/EventStreams)
service, which delivers every change made to any Wikimedia project as
[server-sent events](https://html.spec.whatwg.org/multipage/server-sent-events.html).
No account or API key is needed.

```
swift run WikiWatch                                  # live dashboard
swift run WikiWatch --plain --wiki enwiki --no-bots  # one line per matching event
swift run WikiWatch --plain --filter '$[?@.length.new > 20000]'
swift run WikiWatch --replay Examples/WikiWatch/sample-recentchange.sse --speed 4
swift run WikiWatch --replay Examples/WikiWatch/sample-recentchange.sse --export out.sse --format sse
swift run WikiWatch --trickle Examples/WikiWatch/sample-recentchange.sse
swift run WikiWatch --help
```

The tool is also available as target `WikiWatch` of `DynamicJSON.xcodeproj`.

**This code is meant to be read.** Besides being a useful tool, `WikiWatch` is a worked example
of how to use _DynamicJSON_ in a real application, and its source files are commented
accordingly: how to read server-sent events, how to navigate and convert `JSON` values, how to
validate JSON with a JSON Schema, how to select values with JSON Path, and how to process a
value that arrives in pieces. `Sources/WikiWatch/main.swift` starts with a map that tells which
file shows what.

## What it shows

| Step | Library feature |
|------|-----------------|
| Read the HTTP response as events, resume after a dropped connection with `Last-Event-ID` | `JSON.events(from:)`, `ServerSentEvent` |
| Decode the data of an event | `ServerSentEvent.json()` |
| Reject events that do not have the expected structure | `JSONSchemaRegistry`, `JSONSchemaValidator` (see `Sources/WikiWatch/Schema.swift`) |
| Select events with `--filter` | `JSONPath`, `JSONPathEvaluator` |
| Read fields | `JSON` subscripts, `intValue`, `stringValue`, ... |
| `--trickle`: show a JSON value that arrives in small pieces | `JSONPartialParser`, `PartialJSON.patch(from:)` |
| `--export FILE --format lines\|sequence\|array\|concatenated\|sse`: save the matching events as a stream | `JSONStreamWriter` (see `Exporter` in `Pipeline.swift`) |

`--filter` takes a JSON Path expression that is evaluated on the event wrapped in an array, so
that the usual filter syntax works: `$[?@.wiki == "dewiki" && @.bot == false]`.

## Sample data

`sample-recentchange.sse` is a capture of the first 70 events of a live session (recorded with
`--record`), followed by three additions that exercise the error handling: one canary event
(`meta.domain` is `canary`, which Wikimedia asks clients to ignore), one event with truncated JSON,
and one event that is missing its `wiki` field. Replaying the file reports
`73 events received, 70 matched, 2 invalid, 1 canary events dropped`.

To record your own capture:

```
swift run WikiWatch --plain --limit 200 --record my-capture.sse
```

Data from Wikimedia EventStreams is available under the terms described at
<https://dumps.wikimedia.org/legal.html>.
