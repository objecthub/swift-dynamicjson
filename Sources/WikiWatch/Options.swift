//
//  Options.swift
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

///
/// The command-line options of `WikiWatch`.
///
struct Options {
  var stream = "recentchange"
  var wikis: Set<String> = []
  var types: Set<String> = []
  var excludeBots = false
  var filter: String? = nil
  var top = 8
  var interval = 0.5
  var limit: Int? = nil
  var plain = false
  var record: String? = nil
  var replay: String? = nil
  var speed = 1.0
  var trickle: String? = nil
  var chunk = 16
  var verbose = false
  
  enum Error: LocalizedError {
    case unknownOption(String)
    case missingValue(String)
    case invalidValue(String, String)
    
    var errorDescription: String? {
      switch self {
        case .unknownOption(let option):
          return "unknown option '\(option)' (try --help)"
        case .missingValue(let option):
          return "option '\(option)' requires a value"
        case .invalidValue(let option, let value):
          return "invalid value '\(value)' for option '\(option)'"
      }
    }
  }
  
  static let usage = """
    WikiWatch: a live dashboard for the Wikimedia "recent changes" event stream.
    
    It reads server-sent events, validates each event with a JSON Schema, selects events with
    JSON Path filters, and aggregates statistics. Built on the streaming support of DynamicJSON.
    
    USAGE: WikiWatch [options]
    
    SOURCES (default: live stream from stream.wikimedia.org)
      --stream NAME        Wikimedia stream to read (default: recentchange)
      --replay FILE        Read a recorded capture instead ('-' reads standard input)
      --speed X            Replay speed relative to the original timing; 0 = as fast as
                           possible (default: 1)
      --record FILE        Save the raw event stream of a live session to FILE
    
    FILTERS (events must match all of them)
      --wiki A,B           Only events of the given wikis, e.g. enwiki,dewiki
      --type A,B           Only events of the given types, e.g. edit,new,log
      --no-bots            Ignore edits by bots
      --filter PATH        JSON Path filter, evaluated on the event wrapped in an array, e.g.
                           '$[?@.wiki == "enwiki" && @.length.new > 5000]'
    
    OUTPUT
      --plain              Print one line per event instead of the dashboard (default if
                           standard output is not a terminal)
      --top N              Number of rows in the dashboard's top lists (default: 8)
      --interval S         Dashboard refresh interval in seconds (default: 0.5)
      --limit N            Stop after N matching events
      --verbose            Report connection problems on standard error
    
    DEMONSTRATION OF INCREMENTAL JSON
      --trickle FILE       Feed the first event of a capture to the partial JSON parser in
                           small fragments and show how its value grows
      --chunk N            Fragment size in bytes for --trickle (default: 16)
    
      -h, --help           Show this help
    """
  
  /// Parses command-line arguments. Returns `nil` if help was requested.
  static func parse(_ arguments: [String]) throws -> Options? {
    var options = Options()
    var args = arguments[...]
    func value(for option: String) throws -> String {
      guard let value = args.popFirst() else {
        throw Error.missingValue(option)
      }
      return value
    }
    func number<T: LosslessStringConvertible>(_ option: String) throws -> T {
      let text = try value(for: option)
      guard let number = T(text) else {
        throw Error.invalidValue(option, text)
      }
      return number
    }
    func list(_ option: String) throws -> Set<String> {
      return Set(try value(for: option).split(separator: ",").map { String($0) })
    }
    while let option = args.popFirst() {
      switch option {
        case "-h", "--help":
          return nil
        case "--stream":
          options.stream = try value(for: option)
        case "--wiki":
          options.wikis = try list(option)
        case "--type":
          options.types = try list(option)
        case "--no-bots":
          options.excludeBots = true
        case "--filter":
          options.filter = try value(for: option)
        case "--top":
          options.top = max(1, try number(option))
        case "--interval":
          options.interval = max(0.05, try number(option))
        case "--limit":
          options.limit = try number(option)
        case "--plain":
          options.plain = true
        case "--record":
          options.record = try value(for: option)
        case "--replay":
          options.replay = try value(for: option)
        case "--speed":
          options.speed = max(0, try number(option))
        case "--trickle":
          options.trickle = try value(for: option)
        case "--chunk":
          options.chunk = max(1, try number(option))
        case "--verbose":
          options.verbose = true
        default:
          throw Error.unknownOption(option)
      }
    }
    return options
  }
}
