//
//  Trickle.swift
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
// INCREMENTAL JSON. Streaming APIs, in particular those of large language models, often send
// ONE JSON value (a tool call, a structured answer) in many small pieces. None of the pieces
// is valid JSON, but applications want to use the partial result while the rest is still
// on its way, for example to fill in a form while the answer is being generated.
//
// `JSONPartialParser` is made for this:
//
//   - `append(_:)` adds the next piece of text (or bytes). It checks the structure of the
//     input as it arrives and throws a `JSON.StreamError` as soon as the input cannot become
//     valid JSON anymore. Pieces may end anywhere, even in the middle of a UTF-8 character.
//   - `snapshot()` returns the best approximation of the value so far, or `nil` if nothing
//     usable has arrived yet. Open strings, arrays, and objects are closed. Members whose key
//     or value is incomplete are left out, and numbers appear only once they are complete,
//     because more digits might follow. Therefore, each snapshot is a prefix of every later
//     snapshot: values only grow.
//   - `finish()` signals the end of the input and returns the complete value. It throws if
//     the value is incomplete.
//
// `PartialJSON` bundles a snapshot with a flag that tells whether it is complete. Its
// `patch(from:)` method computes a JSON Patch (RFC 6902, `JSONPatch`) that turns the previous
// snapshot into this one. This is handy for user interfaces, which can apply only the changes.
//
// When the pieces come from an asynchronous sequence, `JSON.partialValues(from:)` does all of
// this for you, and returns an asynchronous sequence of `PartialJSON` values. If the pieces
// are wrapped in JSON themselves (as in the SSE streams of LLM APIs),
// `JSON.fragments(from:at:)` extracts them with a JSON Pointer first:
//
//     let events = JSON.values(from: bytes, format: .serverSentEvents)
//     let pointer = try JSONPointer("/choices/0/delta/tool_calls/0/function/arguments")
//     let fragments = JSON.fragments(from: events, at: pointer)
//     for try await partial in JSON.partialValues(from: fragments) {
//       print(partial.value)
//     }

///
/// Demonstrates incremental JSON parsing: the first event of a capture is fed to a
/// `JSONPartialParser` in small fragments, as if it arrived slowly over the network. After
/// each fragment, the changes of the parser's best approximation of the value are shown.
///
func runTrickle(path: String, chunk: Int) throws {
  guard let data = FileManager.default.contents(atPath: path) else {
    throw EventSourceError.fileNotFound(path)
  }
  guard let event = JSON.events(from: data).first(where: { !$0.data.contains("\"canary\"") }) else {
    print("no events found in \(path)")
    return
  }
  let bytes = Array(event.data.utf8)
  // The parser is a struct with mutating methods; it keeps all state between calls.
  var parser = JSONPartialParser()
  var previous: PartialJSON? = nil
  var offset = 0
  let width = Dashboard.width
  print("Feeding \(bytes.count) bytes in fragments of \(chunk) bytes to JSONPartialParser\n")
  while offset < bytes.count {
    let end = min(offset + chunk, bytes.count)
    let fragment = String(decoding: bytes[offset..<end], as: UTF8.self)
    // Feed the next fragment. This is where malformed input would throw.
    try parser.append(contentsOf: bytes[offset..<end])
    offset = end
    // The approximation of the value so far; `nil` as long as nothing is usable yet.
    guard let value = try parser.snapshot() else {
      continue
    }
    let partial = PartialJSON(value: value, isComplete: parser.isComplete)
    // A patch is a list of operations (`add`, `remove`, `replace`, `move`, `copy`, `test`),
    // each addressing a location with a JSON Pointer. Without a previous snapshot, the patch
    // transforms `null` into the value.
    let changes = partial.patch(from: previous).operations.map(describe)
    previous = partial
    if !changes.isEmpty {
      let progress = "\(offset)/\(bytes.count)".leftPadding(11)
      print("\(progress)  \(fragment.debugDescription.truncated(24).padding(24))  " +
            "\(changes.joined(separator: "; "))".truncated(max(20, width - 40)))
    }
  }
  // Returns the complete value, or throws if the input ended too early.
  let result = try parser.finish()
  let title = result["title"]?.stringValue ?? "?"
  print("\nComplete: \(title) (\(result["wiki"]?.stringValue ?? "?"))")
}

/// Returns a concise, one-line description of a patch operation. `JSONPatchOperation` is an
/// enumeration with a case for each operation of RFC 6902; paths are `JSONPointer` values.
private func describe(_ operation: JSONPatchOperation) -> String {
  func compact(_ json: JSON) -> String {
    return ((try? json.string()) ?? nil)?.truncated(30) ?? "?"
  }
  func name(_ path: JSONPointer) -> String {
    return path.isRoot ? "(root)" : path.description
  }
  switch operation {
    case .add(let path, let value):
      return "add \(name(path)) \(compact(value))"
    case .replace(let path, let value):
      return "set \(name(path)) \(compact(value))"
    case .remove(let path):
      return "remove \(name(path))"
    default:
      return operation.op.rawValue
  }
}
