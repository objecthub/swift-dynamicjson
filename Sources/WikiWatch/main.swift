//
//  main.swift
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

// WikiWatch: a guided tour of DynamicJSON
// =======================================
//
// This program is meant to be read. It processes a real stream of JSON events, and uses a good
// part of the library on the way. Where to look:
//
//   EventSource.swift   server-sent events: `JSON.events(from:)`, `ServerSentEvent`
//   Pipeline.swift      parsing events, navigating `JSON`, JSON Path queries, using a validator
//   Schema.swift        JSON Schema: `JSONSchemaResource`, `JSONSchemaRegistry`, validators
//   Stats.swift         typed access to JSON values (`stringValue`, `intValue`, ...)
//   Trickle.swift       incremental JSON: `JSONPartialParser`, `PartialJSON`, JSON Patch
//   Options.swift       command-line parsing (plain Swift, no JSON involved)
//   Dashboard.swift     rendering of statistics (plain Swift, no JSON involved)
//
// The overall flow is: bytes -> server-sent events -> JSON values -> validation -> filters ->
// statistics -> terminal.

// Make sure that output appears line by line, even if standard output is a pipe.
setvbuf(stdout, nil, _IOLBF, 0)

do {
  guard let options = try Options.parse(Array(CommandLine.arguments.dropFirst())) else {
    print(Options.usage)
    exit(0)
  }
  if let path = options.trickle {
    try runTrickle(path: path, chunk: options.chunk)
  } else {
    // Ctrl-C cancels the task that reads events, which ends the stream cleanly
    let task = Task {
      try await runMonitor(options: options)
    }
    signal(SIGINT, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    source.setEventHandler {
      task.cancel()
    }
    source.resume()
    try await task.value
  }
} catch {
  fputs("error: \(error.localizedDescription)\n", stderr)
  exit(1)
}
