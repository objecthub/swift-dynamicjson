//
//  main.swift
//  JSONPathTool
//
//  Created by Matthias Zenger on 18/02/2024.
//  Copyright © 2024 Matthias Zenger. All rights reserved.
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

let jsonStr = """
{
  "store": {
    "book": [
      {
        "category": "reference",
        "author": "Nigel Rees",
        "title": "Sayings of the Century",
        "display-price": 8.95,
        "bargain": true,
        "foo": null
      },
      {
        "category": "fiction",
        "author": "Evelyn Waugh",
        "title": "Sword of Honour",
        "display-price": 12.99,
        "bargain": false,
        "foo": null
      },
      {
        "category": "fiction",
        "author": "Herman Melville",
        "title": "Moby Dick",
        "isbn": "0-553-21311-3",
        "display-price": 8.99,
        "bargain": true,
        "foo": 1
      },
      {
        "category": "fiction",
        "author": "J. R. R. Tolkien",
        "title": "The Lord of the Rings",
        "isbn": "0-395-19395-8",
        "display-price": 22.99,
        "bargain": false,
        "foo": 2
      }
    ],
    "less": [
      {
        "category": "reference",
        "author": "Nigel Rees",
        "title": "Sayings of the Century",
        "display-price": 8.95,
        "bargain": true,
        "foo": null
      },
      {
        "category": "fiction",
        "author": "J. R. R. Tolkien",
        "title": "The Lord of the Rings",
        "isbn": "0-395-19395-8",
        "display-price": 22.99,
        "bargain": false,
        "foo": 2
      }
    ],
    "bicycle": {
      "color": "red",
      "display-price": 19.95,
      "foo:bar": "fooBar",
      "dot.notation": "new",
      "dash-notation": "dashes"
    }
  }
}
"""

let jsonStr2 = """
{
  "a": [3, 5, 1, 2, 4, 6,
        {"b": "j"},
        {"b": "k"},
        {"b": {}},
        {"b": "kilo"}
       ],
  "o": {"p": 1, "q": 2, "r": 3, "s": 5, "t": {"u": 6}},
  "e": "f"
}
"""

let jsonStr3 = """
{
  "obj": {"x": "y"},
  "arr": [2, 3]
}
"""

let json = try JSON(string: jsonStr)

while true {
  print("> ", terminator: "")
  guard let query = readLine()?.trimmingCharacters(in: .whitespaces),
        !query.isEmpty else {
    break
  }
  do {
    var parser = JSONPathParser(string: query)
    let path = try parser.parse()
    let evaluator = JSONPathEvaluator(value: json)
    let result = try evaluator.query(path).values
    var i = 0
    for res in result {
      print("[\(i)]")
      print(res)
      i += 1
    }
  } catch let e {
    print("error:", e.localizedDescription)
  }
}
