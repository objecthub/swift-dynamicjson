//
//  Dashboard.swift
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
/// Rendering of statistics for the terminal, and of events as lines of text.
///
struct Dashboard {
  static let hideCursor = "\u{1B}[?25l"
  static let showCursor = "\u{1B}[?25h"
  
  let top: Int
  let source: String
  
  /// Is standard output a terminal?
  static var isTerminal: Bool {
    return isatty(STDOUT_FILENO) != 0
  }
  
  /// The width of the terminal in columns.
  static var width: Int {
    var size = winsize()
    if ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0 && size.ws_col > 0 {
      return Int(size.ws_col)
    }
    return 100
  }
  
  // MARK: - Events
  
  /// Returns a one-line description of an event.
  static func line(for json: JSON) -> String {
    let time = String((json["meta"]?["dt"]?.stringValue ?? "").dropFirst(11).prefix(8))
    let wiki = json["wiki"]?.stringValue ?? "?"
    let type = json["type"]?.stringValue ?? "?"
    var size = ""
    if let new = json["length"]?["new"]?.intValue {
      let delta = new - (json["length"]?["old"]?.intValue ?? 0)
      size = delta >= 0 ? "+\(delta)" : "\(delta)"
    }
    let bot = json["bot"]?.boolValue == true ? " [bot]" : ""
    let user = json["user"]?.stringValue ?? "?"
    let title = json["title"]?.stringValue ?? "?"
    return "\(time) \(wiki.padding(18)) \(type.padding(10)) \(size.leftPadding(8))  " +
           "\(user)\(bot): \(title)"
  }
  
  // MARK: - Dashboard
  
  /// Returns the text that replaces the content of the terminal.
  func render(_ stats: Stats) -> String {
    let width = Dashboard.width
    var lines: [String] = []
    let elapsed = Int(Date().timeIntervalSince(stats.started))
    lines.append("WikiWatch · \(self.source) · " +
                 String(format: "%02d:%02d:%02d", elapsed / 3600, elapsed / 60 % 60, elapsed % 60))
    lines.append("")
    lines.append(String(format: "%.1f events/s   ", stats.rate) +
                 "matched \(stats.matched) of \(stats.received)   " +
                 "invalid \(stats.invalid)   canary \(stats.canary)")
    let total = max(1, stats.matched)
    lines.append("humans \(stats.humans * 100 / total)%   bots \(stats.bots * 100 / total)%   " +
                 "new pages \(stats.newPages)   minor edits \(stats.minorEdits)")
    if let biggest = stats.biggest {
      lines.append("biggest change \(biggest.delta >= 0 ? "+" : "")\(biggest.delta) bytes: " +
                   "\(biggest.title) (\(biggest.wiki))")
    }
    lines.append("")
    self.section("Event types", Stats.top(stats.byType, self.top), into: &lines)
    self.section("Wikis", Stats.top(stats.byWiki, self.top), into: &lines)
    self.section("Pages", Stats.top(stats.byPage, self.top), into: &lines)
    self.section("Users", Stats.top(stats.byUser, self.top), into: &lines)
    lines.append("Press Ctrl-C to stop.")
    return "\u{1B}[H" + lines.map { $0.truncated(width) + "\u{1B}[K\n" }.joined() + "\u{1B}[J"
  }
  
  private func section(_ title: String,
                       _ rows: [(name: String, count: Int)],
                       into lines: inout [String]) {
    lines.append(title)
    let maximum = max(1, rows.first?.count ?? 1)
    for row in rows {
      let bar = String(repeating: "█", count: max(1, row.count * 24 / maximum))
      lines.append("  " + row.name.truncated(40).padding(40) + " " +
                   String(row.count).leftPadding(6) + " " + bar)
    }
    lines.append("")
  }
}

extension String {
  
  /// Pads this string with spaces on the right to a length of at least `length`.
  func padding(_ length: Int) -> String {
    return self.count >= length ? self : self + String(repeating: " ", count: length - self.count)
  }
  
  /// Pads this string with spaces on the left to a length of at least `length`.
  func leftPadding(_ length: Int) -> String {
    return self.count >= length ? self : String(repeating: " ", count: length - self.count) + self
  }
  
  /// Shortens this string to at most `length` characters, marking omissions with an ellipsis.
  func truncated(_ length: Int) -> String {
    return self.count <= length ? self : String(self.prefix(max(0, length - 1))) + "…"
  }
}
