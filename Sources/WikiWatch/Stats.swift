//
//  Stats.swift
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
// Reading typed values out of a `JSON` document. Since JSON documents from the outside world
// are not guaranteed to have the structure you expect, `JSON` provides optional accessors
// instead of requiring you to define `Codable` types for everything. (If you do want a
// strongly typed model, `json.coerce()` decodes a `JSON` value into any `Decodable` type, and
// `JSON(encodable:)` goes the other way.)

///
/// Statistics about the recent changes seen so far.
///
struct Stats {
  var received = 0
  var matched = 0
  var invalid = 0
  var canary = 0
  var bots = 0
  var humans = 0
  var newPages = 0
  var minorEdits = 0
  var byType: [String : Int] = [:]
  var byWiki: [String : Int] = [:]
  var byPage: [String : Int] = [:]
  var byUser: [String : Int] = [:]
  var biggest: (title: String, wiki: String, delta: Int)? = nil
  var lastError: String? = nil
  let started = Date()
  private(set) var rate = 0.0
  private var rateCount = 0
  private var rateTime = Date()
  
  /// Records an event that passed all filters.
  mutating func record(_ json: JSON) {
    self.matched += 1
    // `stringValue` is `nil` unless the value is a JSON string; `?? "?"` supplies a default.
    let type = json["type"]?.stringValue ?? "?"
    self.byType[type, default: 0] += 1
    if let wiki = json["wiki"]?.stringValue {
      self.byWiki[wiki, default: 0] += 1
    }
    if let title = json["title"]?.stringValue {
      self.byPage[title, default: 0] += 1
    }
    if let user = json["user"]?.stringValue {
      self.byUser[user, default: 0] += 1
    }
    // Comparing an optional `Bool` with `true` is a compact way to say "present and true".
    if json["bot"]?.boolValue == true {
      self.bots += 1
    } else {
      self.humans += 1
    }
    if type == "new" {
      self.newPages += 1
    }
    if json["minor"]?.boolValue == true {
      self.minorEdits += 1
    }
    // `intValue` returns an `Int` for JSON integers, and `nil` for everything else, including
    // floating-point numbers such as `1.5`. `doubleValue` accepts both integers and floats.
    // `JSON` keeps the two apart (cases `integer(Int64)` and `float(Double)`), so large
    // integers do not lose precision.
    if type == "edit" || type == "new", let new = json["length"]?["new"]?.intValue {
      let delta = new - (json["length"]?["old"]?.intValue ?? 0)
      if abs(delta) > abs(self.biggest?.delta ?? 0) {
        self.biggest = (json["title"]?.stringValue ?? "?", json["wiki"]?.stringValue ?? "?", delta)
      }
    }
  }
  
  /// Updates the exponentially weighted average of the number of matching events per second.
  mutating func updateRate(now: Date = Date()) {
    let elapsed = now.timeIntervalSince(self.rateTime)
    guard elapsed > 0 else {
      return
    }
    let instant = Double(self.matched - self.rateCount) / elapsed
    self.rate = self.rate == 0.0 ? instant : 0.3 * instant + 0.7 * self.rate
    self.rateCount = self.matched
    self.rateTime = now
  }
  
  /// Returns the `n` entries with the highest counts.
  static func top(_ counts: [String : Int], _ n: Int) -> [(name: String, count: Int)] {
    return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                 .prefix(n)
                 .map { (name: $0.key, count: $0.value) }
  }
}
