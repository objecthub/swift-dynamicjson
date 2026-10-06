//
//  Pipeline.swift
//  WikiWatch
//
//  Created by Matthias Zenger on 05/10/2026.
//  Copyright © 2026 Matthias Zenger. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import DynamicJSON

// WHAT THIS FILE SHOWS
// ====================
//
//   - turning the data of a server-sent event into a `JSON` value
//   - navigating a `JSON` value (subscripts, optional chaining, typed accessors)
//   - validating a `JSON` value with a JSON Schema (`JSONSchemaValidator`)
//   - selecting values with a JSON Path query (`JSONPath`, `JSONPathEvaluator`)

///
/// The processing pipeline: it turns server-sent events into JSON values, drops canary
/// events, validates the remaining events with a JSON Schema, applies the filters of the
/// command line, and collects statistics.
///
final class Pipeline {
  let options: Options
  // Created once and used for all events. See `Schema.swift` for how it is set up.
  private let validator: JSONSchemaValidator
  // A parsed JSON Path query. Parsing a query is separate from running it, so this is done
  // only once.
  private let filter: JSONPath?
  // The environment of a JSON Path evaluator defines the functions that are available in
  // filters (`length`, `count`, `match`, `search`, `value`). Creating an environment is not
  // free, so all evaluators share one. To add your own functions to filters, subclass
  // `JSONPathEnvironment` and override `initialize()`.
  private let environment = JSONPathEnvironment()
  private(set) var stats = Stats()
  
  init(options: Options) throws {
    self.options = options
    self.validator = try RecentChangeSchema.makeValidator()
    if let filter = options.filter {
      // `JSONPath(query:)` throws for queries that are not valid RFC 9535 JSON Path. Doing
      // this in the initializer makes the tool report mistakes before any event is read.
      self.filter = try JSONPath(query: filter)
    } else {
      self.filter = nil
    }
  }
  
  /// Processes an event. Returns the event's JSON value if it passed all checks and filters.
  func process(_ event: ServerSentEvent) -> JSON? {
    self.stats.received += 1
    let json: JSON
    do {
      // The data of an event is text. `JSON(string:)` (which `event.json()` uses) parses it
      // into a `JSON` value, which is an enumeration with the cases `null`, `boolean`,
      // `integer`, `float`, `string`, `array`, and `object`. It throws if the text is not
      // valid JSON, e.g. if a transmission was cut off.
      json = try event.json()
    } catch {
      self.stats.invalid += 1
      self.stats.lastError = "malformed JSON: \(error.localizedDescription)"
      return nil
    }
    // Wikimedia emits canary events for monitoring, which have to be ignored.
    //
    // Navigating a `JSON` value: subscripts with a member name (`json["meta"]`) or an index
    // (`json[0]`) return an optional `JSON`, which is `nil` if the value is not an object (or
    // array), or if the member (or element) does not exist. This is why accesses can be
    // chained with `?` without any risk of a crash. The accessors `stringValue`, `intValue`,
    // `doubleValue`, `boolValue`, `arrayValue`, and `objectValue` convert to Swift types and
    // return `nil` if the value is of a different kind.
    //
    // The same expression with dynamic member lookup is `json.meta?.domain?.stringValue`. We
    // use subscripts throughout this tool, since members such as `type` or `description`
    // clash with properties of `JSON` itself. A third option are references with JSON Pointer
    // syntax, which also work with deeply nested values: `try json[ref: "/meta/domain"]`.
    if json["meta"]?["domain"]?.stringValue == "canary" {
      self.stats.canary += 1
      return nil
    }
    // Validating returns a `JSONSchemaValidationResult`, which does not throw for invalid
    // instances. `isValid` tells whether validation succeeded. If it did not, `errors` lists
    // the problems. Each error has the `value` that failed (a `LocatedJSON`, i.e. a value
    // together with its location in the instance), the `location` of the violated keyword in
    // the schema, and a `message` explaining the reason. The result contains annotations as
    // well, for instance `formatConstraints`, `tags` (deprecated, read-only, write-only), and
    // `defaults` (default values that were found in the schema for missing properties).
    let result = self.validator.validate(json)
    if !result.isValid {
      self.stats.invalid += 1
      if let error = result.errors.first {
        self.stats.lastError = "\(error.message.reason.reason) at \(error.location)"
      }
      return nil
    }
    guard self.matches(json) else {
      return nil
    }
    self.stats.record(json)
    return json
  }
  
  func updateRate() {
    self.stats.updateRate()
  }
  
  private func matches(_ json: JSON) -> Bool {
    let wiki = json["wiki"]?.stringValue ?? ""
    if !self.options.wikis.isEmpty && !self.options.wikis.contains(wiki) {
      return false
    }
    let type = json["type"]?.stringValue ?? ""
    if !self.options.types.isEmpty && !self.options.types.contains(type) {
      return false
    }
    if self.options.excludeBots && json["bot"]?.boolValue == true {
      return false
    }
    if let filter = self.filter {
      // JSON Path queries start at the root of a document. A filter selector `[?<condition>]`
      // tests the children of the node it is applied to. In order to let users write
      // conditions about the event itself, e.g. `$[?@.wiki == "enwiki"]`, the event is
      // wrapped in an array with a single element. If the condition holds, the query returns
      // that element.
      //
      // `json.query("$...")` is a shortcut for the same thing on a single value; an evaluator
      // can be created once and used for many queries, and it lets us share the environment.
      let evaluator = JSONPathEvaluator(value: .array([json]), env: self.environment)
      // The result is an array of `LocatedJSON` values: each matching value together with
      // its location (a normalized path such as `$[0]['wiki']`). Use `.values` or `.locations`
      // to get just one of them. Queries can fail while they are evaluated (e.g. a function is
      // applied to an argument of the wrong type); we treat this as "no match".
      guard let nodes = try? evaluator.query(filter), !nodes.isEmpty else {
        return false
      }
    }
    return true
  }
}

/// Writes the events that passed the filters as a stream of JSON values to a file.
///
/// This shows how to create streams with DynamicJSON; it is the counterpart of reading
/// streams. A `JSONStreamWriter` does not do any I/O. It is created for one of the formats
/// (`.lines`, `.sequence`, `.concatenated`, `.arrayElements`, `.serverSentEvents`), turns each
/// value into the bytes that belong to it, including the framing of the format, and tells
/// what to append to the output. `finish()` returns the closing bytes, e.g. the `]` of an
/// array. Everything written can be read again with `JSON.values(from:format:)`.
///
/// The same functionality is available as an asynchronous sequence: `JSON.stream(values,
/// format:)` turns an `AsyncSequence` of `JSON` values into an `AsyncSequence` of `Data`
/// chunks, which is what a server needs for a streaming response, and
/// `JSON.write(values, to: url, format:)` writes values to a file in one go.
final class Exporter {
  private var writer: JSONStreamWriter
  private let handle: FileHandle
  private let format: JSON.StreamFormat
  let toStandardOutput: Bool
  
  init(path: String, format: JSON.StreamFormat) throws {
    // `.sortedKeys` makes the output independent of the (random) order of dictionary keys.
    self.writer = try JSONStreamWriter(format: format, options: JSON.StreamWriteOptions(
                                        formatting: [.withoutEscapingSlashes, .sortedKeys]))
    self.format = format
    self.toStandardOutput = path == "-"
    if self.toStandardOutput {
      self.handle = FileHandle.standardOutput
    } else {
      guard FileManager.default.createFile(atPath: path, contents: nil),
            let handle = FileHandle(forWritingAtPath: path) else {
        throw EventSourceError.fileNotFound(path)
      }
      self.handle = handle
    }
  }
  
  func write(_ json: JSON) throws {
    if self.format == .serverSentEvents {
      // Events can have a name; clients can use it to tell different kinds of events apart
      self.handle.write(try self.writer.write(json, event: "recentchange"))
    } else {
      self.handle.write(try self.writer.write(json))
    }
  }
  
  func finish() throws {
    self.handle.write(try self.writer.finish())
    if !self.toStandardOutput {
      try self.handle.close()
    }
  }
}

/// Runs the monitor: reads events, and either prints them or updates the dashboard.
func runMonitor(options: Options) async throws {
  let pipeline = try Pipeline(options: options)
  let exporter = try options.export.map { try Exporter(path: $0, format: options.exportFormat) }
  let recorder = try options.record.map { try Recorder(path: $0) }
  let events: AsyncThrowingStream<ServerSentEvent, Error>
  if let path = options.replay {
    events = try EventSource.replay(path: path, speed: options.speed)
  } else {
    events = EventSource.live(stream: options.stream, recorder: recorder, verbose: options.verbose)
  }
  // Standard output carries the exported data if the export goes there
  let exportsToStandardOutput = exporter?.toStandardOutput ?? false
  let showDashboard = !options.plain && Dashboard.isTerminal && !exportsToStandardOutput
  let dashboard = Dashboard(top: options.top,
                            source: options.replay.map { "replay \($0)" } ?? options.stream)
  if showDashboard {
    print(Dashboard.hideCursor, terminator: "")
  }
  var lastRender = Date.distantPast
  do {
    for try await event in events {
      if let json = pipeline.process(event) {
        try exporter?.write(json)
        if !showDashboard && !exportsToStandardOutput {
          print(Dashboard.line(for: json))
        }
      }
      if showDashboard && Date().timeIntervalSince(lastRender) >= options.interval {
        pipeline.updateRate()
        print(dashboard.render(pipeline.stats), terminator: "")
        fflush(stdout)
        lastRender = Date()
      }
      if let limit = options.limit, pipeline.stats.matched >= limit {
        break
      }
    }
  } catch is CancellationError {
    // Interrupted by the user
  }
  recorder?.flush()
  try exporter?.finish()
  if showDashboard {
    pipeline.updateRate()
    print(dashboard.render(pipeline.stats), terminator: "")
    print(Dashboard.showCursor, terminator: "")
  }
  let stats = pipeline.stats
  fputs("\(stats.received) events received, \(stats.matched) matched, " +
        "\(stats.invalid) invalid, \(stats.canary) canary events dropped\n", stderr)
  if let error = stats.lastError, stats.invalid > 0 {
    fputs("last validation problem: \(error)\n", stderr)
  }
}
