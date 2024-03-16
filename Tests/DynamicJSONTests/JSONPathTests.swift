//
//  JSONPathTests.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 14/02/2024.
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

import XCTest
@testable import DynamicJSON

final class JSONPathTests: XCTestCase {
  private func parse(_ str: String, strict: Bool = true) -> JSONPath? {
    var parser = JSONPathParser(string: str, strict: strict)
    return try? parser.parse()
  }
  
  func testSimplePaths() {
    XCTAssertEqual(parse("$"), .self)
    XCTAssertEqual(parse(" $", strict: false), .self)
    XCTAssertEqual(parse("$ ", strict: false), .self)
    XCTAssertNil(parse("$ ", strict: true))
    XCTAssertEqual(parse("$.foo"), .children(.self, .member("foo")))
    XCTAssertEqual(parse("$ .foo"), .children(.self, .member("foo")))
    XCTAssertEqual(parse("$ .foo. bar", strict: false),
                   .children(.children(.self, .member("foo")), .member("bar")))
    XCTAssertEqual(parse("$[0]"), .children(.self, .index(0)))
    XCTAssertEqual(parse("$[ 1 ]"), .children(.self, .index(1)))
    XCTAssertEqual(parse("$ [23]"), .children(.self, .index(23)))
    XCTAssertEqual(parse("$[0][12]"), .children(.children(.self, .index(0)), .index(12)))
    XCTAssertEqual(parse("$[0].foo[12]"),
                   .children(.children(.children(.self, .index(0)), .member("foo")), .index(12)))
    XCTAssertEqual(parse("$[ 0 ] .foo[ 12 ]"),
                   .children(.children(.children(.self, .index(0)), .member("foo")), .index(12)))
    XCTAssertEqual(parse("$ [0]  .  foo [12]", strict: false),
                   .children(.children(.children(.self, .index(0)), .member("foo")), .index(12)))
    XCTAssertEqual(parse("$.foo[0][12].b[3]"),
                   .children(.children(.children(.children(.children(.self, .member("foo")),
                                                           .index(0)), .index(12)), .member("b")),
                             .index(3)))
    XCTAssertEqual(parse("$.foo[0]  [12].b  [3].AB"),
                   .children(.children(.children(.children(.children(
                    .children(.self, .member("foo")), .index(0)), .index(12)),
                                                 .member("b")), .index(3)), .member("AB")))
    XCTAssertEqual(parse("$.*[0][*].b[3]"),
                   .children(.children(.children(.children(.children(.self, .wildcard), .index(0)),
                                                 .wildcard), .member("b")), .index(3)))
  }
  
  func testDescendantsPaths() {
    XCTAssertEqual(parse("$..foo"), .descendants(.self, .member("foo")))
    XCTAssertEqual(parse("$ ..foo"), .descendants(.self, .member("foo")))
    XCTAssertEqual(parse("$ ..foo.. bar", strict: false),
                   .descendants(.descendants(.self, .member("foo")), .member("bar")))
    XCTAssertEqual(parse("$..foo..bar"),
                   .descendants(.descendants(.self, .member("foo")), .member("bar")))
    XCTAssertEqual(parse("$..[0]"), .descendants(.self, .index(0)))
    XCTAssertEqual(parse("$  ..[23]"), .descendants(.self, .index(23)))
    XCTAssertEqual(parse("$[0]..[12]"), .descendants(.children(.self, .index(0)), .index(12)))
    XCTAssertEqual(parse("$[0]..  foo[12]", strict: false),
                   .children(.descendants(.children(.self, .index(0)), .member("foo")), .index(12)))
    XCTAssertEqual(parse("$[0]..foo[ 12 ]"),
                   .children(.descendants(.children(.self, .index(0)), .member("foo")), .index(12)))
    XCTAssertEqual(parse("$ [ 0 ]  ..foo..[1]", strict: false),
                   .descendants(.descendants(.children(.self, .index(0)), .member("foo")), .index(1)))
    XCTAssertEqual(parse("$..foo[0][12]..b[3]"),
                   .children(.descendants(.children(.children(
                    .descendants(.self, .member("foo")), .index(0)), .index(12)), .member("b")),
                             .index(3)))
  }
  
  func testBasicSelectors() {
    XCTAssertEqual(parse("$['foo']"), parse("$.foo"))
    XCTAssertEqual(parse("$['foo']['bar']"), parse("$.foo.bar"))
    XCTAssertEqual(parse("$[ \"foo\"] [\"bar\" ]  [  \"g\"  ]"), parse("$.foo.bar.g"))
    XCTAssertEqual(parse("$[:]"), .children(.self, .slice(nil, nil, nil)))
    XCTAssertEqual(parse("$[1:].foo"),
                   .children(.children(.self, .slice(1, nil, nil)), .member("foo")))
    XCTAssertEqual(parse("$.f[1:2]"),
                   .children(.children(.self, .member("f")), .slice(1, 2, nil)))
    XCTAssertEqual(parse("$.f[1:22:3]"),
                   .children(.children(.self, .member("f")), .slice(1, 22, 3)))
    XCTAssertEqual(parse("$.f[:222:-3]"),
                   .children(.children(.self, .member("f")), .slice(nil, 222, -3)))
    XCTAssertEqual(parse("$.f[::123]"),
                   .children(.children(.self, .member("f")), .slice(nil, nil, 123)))
    XCTAssertEqual(parse("$.f[-1::2]"),
                   .children(.children(.self, .member("f")), .slice(-1, nil, 2)))
    XCTAssertEqual(parse("$.f[-1:-23:]"),
                   .children(.children(.self, .member("f")), .slice(-1, -23, nil)))
    XCTAssertEqual(parse("$.f[:-23:]"),
                   .children(.children(.self, .member("f")), .slice(nil, -23, nil)))
    XCTAssertEqual(parse("$.f[:23456]"),
                   .children(.children(.self, .member("f")), .slice(nil, 23456, nil)))
    XCTAssertEqual(parse("$[1:][:2]['x'][:3:4]"),
                   .children(.children(.children(.children(.self, .slice(1, nil, nil)),
                                                 .slice(nil, 2, nil)), .member("x")),
                             .slice(nil, 3, 4)))
    XCTAssertEqual(parse("$[ : ]"), .children(.self, .slice(nil, nil, nil)))
    XCTAssertEqual(parse("$[ 1 :].foo"),
                   .children(.children(.self, .slice(1, nil, nil)), .member("foo")))
    XCTAssertEqual(parse("$.f[1 : 2 ]"),
                   .children(.children(.self, .member("f")), .slice(1, 2, nil)))
    XCTAssertEqual(parse("$.f[1: -22 :3]"),
                   .children(.children(.self, .member("f")), .slice(1, -22, 3)))
    XCTAssertEqual(parse("$.f[:0: -3 ]"),
                   .children(.children(.self, .member("f")), .slice(nil, 0, -3)))
    XCTAssertEqual(parse("$.f[ : : 0]"),
                   .children(.children(.self, .member("f")), .slice(nil, nil, 0)))
    XCTAssertEqual(parse("$.f[  -1  ::2  ]"),
                   .children(.children(.self, .member("f")), .slice(-1, nil, 2)))
    XCTAssertEqual(parse("$.f[ -1  : -23  :   ]"),
                   .children(.children(.self, .member("f")), .slice(-1, -23, nil)))
  }
  
  func testFilterSelectors() {
    XCTAssertEqual(parse("$[? true]"), .children(.self, .filter(.true)))
    XCTAssertEqual(parse("$[?(true)]"), .children(.self, .filter(.true)))
    XCTAssertEqual(parse("$[? !false]"), .children(.self, .filter(.prefix(.not, .false))))
    XCTAssertEqual(parse("$[? -(true)]"), .children(.self, .filter(.prefix(.negate, .true))))
    XCTAssertEqual(parse("$[? 123]"), .children(.self, .filter(.integer(123))))
    XCTAssertEqual(parse("$[? -12]"), .children(.self, .filter(.integer(-12))))
    XCTAssertEqual(parse("$[? 0.123]"), .children(.self, .filter(.float(0.123))))
    XCTAssertEqual(parse("$[?  -123.45e-2 ]"), .children(.self, .filter(.float(-123.45e-2))))
    XCTAssertEqual(parse("$[? 1 == 2]"),
                   .children(.self, .filter(.operation(.integer(1), .equals, .integer(2)))))
    XCTAssertEqual(parse("$[? -1 == 2]"),
                   .children(.self, .filter(.operation(.integer(-1), .equals, .integer(2)))))
    XCTAssertEqual(parse("$[? 1 == -2]"),
                   .children(.self, .filter(.operation(.integer(1), .equals, .integer(-2)))))
    XCTAssertEqual(parse("$[? 1234 != 56]"),
                   .children(.self, .filter(.operation(.integer(1234), .notEquals, .integer(56)))))
    XCTAssertEqual(parse("$[? 1.2 > 0.1]"),
                   .children(.self, .filter(.operation(.float(1.2), .greaterThan, .float(0.1)))))
    XCTAssertEqual(parse("$[? 1.2>0.1]"),
                   .children(.self, .filter(.operation(.float(1.2), .greaterThan, .float(0.1)))))
    XCTAssertEqual(parse("$[? 0 < 0.1 ]"),
                   .children(.self, .filter(.operation(.integer(0), .lessThan, .float(0.1)))))
    XCTAssertEqual(parse("$[? 1.2>= 0.1]"),
                   .children(.self, .filter(.operation(.float(1.2), .greaterThanEquals, .float(0.1)))))
    XCTAssertEqual(parse("$[? 0 <=0.1]"),
                   .children(.self, .filter(.operation(.integer(0), .lessThanEquals, .float(0.1)))))
    XCTAssertEqual(parse("$[? 1 + 2 == 3]"),
                   .children(.self, .filter(.operation(.operation(.integer(1), .plus, .integer(2)),
                                                       .equals, .integer(3)))))
    XCTAssertEqual(parse("$[? 1 == 2 + 3]"),
                   .children(.self, .filter(.operation(.integer(1),
                                                       .equals,
                                                       .operation(.integer(2), .plus, .integer(3))))))
    XCTAssertEqual(parse("$[? 1==2 + 3 * 4]"),
                   .children(.self, .filter(.operation(.integer(1), .equals,
                                                       .operation(.integer(2), .plus,
                                                                  .operation(.integer(3), .mult, .integer(4)))))))
    XCTAssertEqual(parse("$[? 1*2+3 == 4]"),
                   .children(.self, .filter(.operation(
                    .operation(.operation(.integer(1), .mult, .integer(2)),
                               .plus, .integer(3)), .equals, .integer(4)))))
    XCTAssertEqual(parse("$[? 1*2+3==-4]"),
                   .children(.self, .filter(.operation(
                    .operation(.operation(.integer(1), .mult, .integer(2)), .plus, .integer(3)),
                    .equals, .integer(-4)))))
    XCTAssertEqual(parse("$[? 1*2+3== - (1 + 2)]"),
                   .children(.self, .filter(.operation(.operation(
                    .operation(.integer(1), .mult, .integer(2)), .plus, .integer(3)), .equals,
                                                       .prefix(.negate, .operation(.integer(1),
                                                                                   .plus, .integer(2)))))))
    XCTAssertEqual(parse("$[? @.id]"),
                   .children(.self, .filter(.singularQuery(.children(.current, .member("id"))))))
    XCTAssertEqual(parse("$[? @.id==42]"),
                   .children(.self, .filter(.operation(.singularQuery(
                    .children(.current, .member("id"))), .equals, .integer(42)))))
    XCTAssertEqual(parse("$[? function ()]", strict: false), .children(.self, .filter(.call("function", []))))
    XCTAssertEqual(parse("$[? fun()+FUN(1.2)* f (3, 4) - g(1,2,3)]", strict: false),
                   .children(.self, .filter(
                    .operation(.operation(.call("fun", []), .plus,
                      .operation(.call("FUN", [.float(1.2)]), .mult,
                                 .call("f", [.integer(3), .integer(4)]))), .minus,
                               .call("g", [.integer(1), .integer(2), .integer(3)])))))
  }
  
  func testParsingSucceeds() {
    XCTAssertNotNil(parse("$[1:3]"))
    XCTAssertNotNil(parse("$[0:5]"))
    XCTAssertNotNil(parse("$[7:10]"))
    XCTAssertNotNil(parse("$[1:3]"))
    XCTAssertNotNil(parse("$[1:10]"))
    XCTAssertNotNil(parse("$[2:113667776004]"))
    XCTAssertNotNil(parse("$[2:-113667776004:-1]"))
    XCTAssertNotNil(parse("$[-113667776004:2]"))
    XCTAssertNotNil(parse("$[113667776004:2:-1]"))
    XCTAssertNotNil(parse("$[-4:-5]"))
    XCTAssertNotNil(parse("$[-4:-4]"))
    XCTAssertNotNil(parse("$[-4:-3]"))
    XCTAssertNotNil(parse("$[-4:1]"))
    XCTAssertNotNil(parse("$[-4:2]"))
    XCTAssertNotNil(parse("$[-4:3]"))
    XCTAssertNotNil(parse("$[3:0:-2]"))
    XCTAssertNotNil(parse("$[7:3:-1]"))
    XCTAssertNotNil(parse("$[0:3:-2]"))
    XCTAssertNotNil(parse("$[::-2]"))
    XCTAssertNotNil(parse("$[1:]"))
    XCTAssertNotNil(parse("$[3::-1]"))
    XCTAssertNotNil(parse("$[:2]"))
    XCTAssertNotNil(parse("$[:]"))
    XCTAssertNotNil(parse("$[:]"))
    XCTAssertNotNil(parse("$[::]"))
    XCTAssertNotNil(parse("$[:2:-1]"))
    XCTAssertNotNil(parse("$[3:-4]"))
    XCTAssertNotNil(parse("$[3:-3]"))
    XCTAssertNotNil(parse("$[3:-2]"))
    XCTAssertNotNil(parse("$[2:1]"))
    XCTAssertNotNil(parse("$[0:0]"))
    XCTAssertNotNil(parse("$[0:1]"))
    XCTAssertNotNil(parse("$[-1:]"))
    XCTAssertNotNil(parse("$[-2:]"))
    XCTAssertNotNil(parse("$[-4:]"))
    XCTAssertNotNil(parse("$[0:3:2]"))
    XCTAssertNotNil(parse("$[0:3:0]"))
    XCTAssertNotNil(parse("$[0:3:1]"))
    XCTAssertNotNil(parse("$[010:024:010]", strict: false))
    XCTAssertNil(parse("$[010:024:010]"))
    XCTAssertNotNil(parse("$[0:4:2]"))
    XCTAssertNotNil(parse("$[1:3:]"))
    XCTAssertNotNil(parse("$[::2]"))
    XCTAssertNotNil(parse("$['key']"))
    XCTAssertNotNil(parse("$['missing']"))
    XCTAssertNotNil(parse("$..[0]"))
    XCTAssertNotNil(parse("$['ü']"))
    XCTAssertNotNil(parse("$['two.some']"))
    XCTAssertNotNil(parse("$[\"key\"]"))
    XCTAssertNil(parse("$[]", strict: true))
    XCTAssertNotNil(parse("$['']"))
    XCTAssertNotNil(parse("$[\"\"]"))
    XCTAssertNotNil(parse("$[-2]"))
    XCTAssertNotNil(parse("$[2]"))
    XCTAssertNotNil(parse("$[0]"))
    XCTAssertNotNil(parse("$[1]"))
    XCTAssertNotNil(parse("$[0]"))
    XCTAssertNotNil(parse("$.*[1]"))
    XCTAssertNotNil(parse("$[-1]"))
    XCTAssertNotNil(parse("$[-1]"))
    XCTAssertNotNil(parse("$[0]"))
    XCTAssertNotNil(parse("$[':']"))
    XCTAssertNotNil(parse("$[']']"))
    XCTAssertNotNil(parse("$['@']"))
    XCTAssertNotNil(parse("$['.']"))
    XCTAssertNotNil(parse("$['.*']"))
    XCTAssertNotNil(parse("$['\"']"))
    XCTAssertNotNil(parse("$['\\\\']"))
    XCTAssertNotNil(parse("$['\\'']"))
    XCTAssertNotNil(parse("$['0']"))
    XCTAssertNotNil(parse("$['$']"))
    XCTAssertNotNil(parse("$[':@.\"$,*\\'\\\\']"))
    XCTAssertNil(parse("$['single'quote']"))
    XCTAssertNotNil(parse("$[',']"))
    XCTAssertNotNil(parse("$['*']"))
    XCTAssertNotNil(parse("$['*']"))
    XCTAssertNotNil(parse("$[ 'a' ]"))
    XCTAssertNotNil(parse("$['ni.*']"))
    XCTAssertNil(parse("$['two'.'some']"))
    XCTAssertNil(parse("$[two.some]"))
    XCTAssertNotNil(parse("$[*]"))
    XCTAssertNotNil(parse("$[*]"))
    XCTAssertNotNil(parse("$[*]"))
    XCTAssertNotNil(parse("$[*]"))
    XCTAssertNotNil(parse("$[*]"))
    XCTAssertNotNil(parse("$[0:2][*]"))
    XCTAssertNotNil(parse("$[*].bar[*]"))
    XCTAssertNotNil(parse("$..[*]"))
    XCTAssertNil(parse("$[key]"))
    XCTAssertNil(parse("@.a"))
    XCTAssertNil(parse("$.['key']"))
    XCTAssertNil(parse("$.[\"key\"]"))
    XCTAssertNil(parse("$.[key]"))
    XCTAssertNotNil(parse("$.key"))
    XCTAssertNotNil(parse("$.key"))
    XCTAssertNotNil(parse("$.key"))
    XCTAssertNotNil(parse("$.id"))
    XCTAssertNotNil(parse("$.key"))
    XCTAssertNotNil(parse("$.key"))
    XCTAssertNotNil(parse("$.missing"))
    XCTAssertNotNil(parse("$[0:2].key"))
    XCTAssertNotNil(parse("$..[1].key"))
    XCTAssertNotNil(parse("$[*].a"))
    XCTAssertNotNil(parse("$[*].a"))
    XCTAssertNotNil(parse("$[*].a"))
    XCTAssertNotNil(parse("$[?(@.id==42)].name"))
    XCTAssertNotNil(parse("$..key"))
    XCTAssertNotNil(parse("$.store..price"))
    XCTAssertNil(parse("$...key"))
    XCTAssertNotNil(parse("$[0,2].key"))
    XCTAssertNotNil(parse("$['one','three'].key"))
    XCTAssertNotNil(parse("$.key-dash"))
    XCTAssertNil(parse("$.\"key\""))
    XCTAssertNil(parse("$..\"key\""))
    XCTAssertNil(parse("$."))
    XCTAssertNotNil(parse("$.in"))
    XCTAssertNotNil(parse("$.length"))
    XCTAssertNotNil(parse("$.null"))
    XCTAssertNotNil(parse("$.true"))
    XCTAssertNil(parse("$.$")) // Might not be consistent with other implementations
    XCTAssertNotNil(parse("$.屬性"))
    XCTAssertNil(parse("$.2")) // Might not be consistent with other implementations
    XCTAssertNil(parse("$.-1")) // Might not be consistent with other implementations
    XCTAssertNil(parse("$.'key'"))
    XCTAssertNil(parse("$..'key'"))
    XCTAssertNil(parse("$.'some.key'"))
    XCTAssertNotNil(parse("$. a", strict: false))
    XCTAssertNil(parse("$. a"))
    XCTAssertNotNil(parse("$.*"))
    XCTAssertNotNil(parse("$.*"))
    XCTAssertNotNil(parse("$.*"))
    XCTAssertNotNil(parse("$.*"))
    XCTAssertNotNil(parse("$.*.bar.*"))
    XCTAssertNotNil(parse("$.*.*"))
    XCTAssertNotNil(parse("$..*"))
    XCTAssertNotNil(parse("$..*"))
    XCTAssertNotNil(parse("$..*"))
    XCTAssertNil(parse("$a"))
    XCTAssertNil(parse(".key"))
    XCTAssertNil(parse("key"))
    XCTAssertNotNil(parse("$[?(@.key)]"))
    XCTAssertNotNil(parse("$..*[?(@.id>2)]"))
    XCTAssertNotNil(parse("$..[?(@.id==2)]"))
    XCTAssertNotNil(parse("$[?(@.key+50==100)]"))
    XCTAssertNotNil(parse("$[?(@.key>42 && @.key<44)]"))
    XCTAssertNotNil(parse("$[?(@.key>0 && false)]"))
    XCTAssertNotNil(parse("$[?(@.key>0 && true)]"))
    XCTAssertNotNil(parse("$[?(@.key>43 || @.key<43)]"))
    XCTAssertNotNil(parse("$[?(@.key>0 || false)]"))
    XCTAssertNotNil(parse("$[?(@.key>0 || true)]"))
    XCTAssertNotNil(parse("$[?(@['key']==42)]"))
    XCTAssertNotNil(parse("$[?(@['@key']==42)]"))
    XCTAssertNotNil(parse("$[?(@[-1]==2)]"))
    XCTAssertNotNil(parse("$[?(@[1]=='b')]"))
    XCTAssertNotNil(parse("$[?(@[1]=='b')]"))
    XCTAssertNotNil(parse("$[?(@)]"))
    XCTAssertNotNil(parse("$[?(@.a && (@.b || @.c))]"))
    XCTAssertNotNil(parse("$[?(@.a && @.b || @.c)]"))
    XCTAssertNotNil(parse("$[?(@.key/10==5)]"))
    XCTAssertNotNil(parse("$[?(@.key-dash == 'value')]"))
    XCTAssertNil(parse("$[?(@.2 == 'second')]"))
    XCTAssertNil(parse("$[?(@.2 == 'third')]"))
    XCTAssertNil(parse("$[?()]"))
    XCTAssertNotNil(parse("$[?(@.key==42)]"))
    XCTAssertNotNil(parse("$[?(@==42)]"))
    XCTAssertNotNil(parse("$[?(@.key==43)]"))
    XCTAssertNotNil(parse("$[?(@.key==42)]"))
    XCTAssertNotNil(parse("$[?(@.id==2)]"))
    XCTAssertNil(parse("$[?(@.d==[\"v1\",\"v2\"])]"))
    XCTAssertNil(parse("$[?(@[0:1]==[1])]"))
    XCTAssertNil(parse("$[?(@.*==[1,2])]"))
    XCTAssertNil(parse("$[?(@.d==[\"v1\",\"v2\"] || (@.d == true))]"))
    XCTAssertNil(parse("$[?(@.d==['v1','v2'])]"))
    XCTAssertNotNil(parse("$[?((@.key<44)==false)]"))
    XCTAssertNotNil(parse("$[?(@.key==false)]"))
    XCTAssertNotNil(parse("$[?(@.key==null)]"))
    XCTAssertNotNil(parse("$[?(@[0:1]==1)]", strict: false))
    XCTAssertNotNil(parse("$[?(@[*]==2)]", strict: false))
    XCTAssertNotNil(parse("$[?(@.*==2)]", strict: false))
    XCTAssertNotNil(parse("$[?(@.key==-0.123e2)]"))
    XCTAssertNil(parse("$[?(@.key==010)]"))
    XCTAssertNil(parse("$[?(@.d=={\"k\":\"v\"})]"))
    XCTAssertNotNil(parse("$[?(@.key==\"value\")]"))
    XCTAssertNotNil(parse("$[?(@.key==\"Motörhead\")]"))
    XCTAssertNotNil(parse("$[?(@.key==\"hi@example.com\")]"))
    XCTAssertNotNil(parse("$[?(@.key==\"some.value\")]"))
    XCTAssertNotNil(parse("$[?(@.key=='value')]"))
    XCTAssertNotNil(parse("$[?(@.key==\"Mot\\u00f6rhead\")]"))
    XCTAssertNotNil(parse("$[?(@.key==true)]"))
    XCTAssertNotNil(parse("$[?(@.key1==@.key2)]"))
    XCTAssertNotNil(parse("$.items[?(@.key==$.value)]"))
    XCTAssertNotNil(parse("$[?(@.key>42)]"))
    XCTAssertNotNil(parse("$[?(@.key>=42)]"))
    XCTAssertNotNil(parse("$[?(@.key>\"VALUE\")]"))
    XCTAssertNil(parse("$[?(@.d in [2, 3])]"))
    XCTAssertNil(parse("$[?(2 in @.d)]"))
    XCTAssertNotNil(parse("$[?(length(@) == 4)]"))
    XCTAssertNil(parse("$[?(@.length() == 4)]"))
    XCTAssertNotNil(parse("$[?(@.length == 4)]"))
    XCTAssertNotNil(parse("$[?(@.key<42)]"))
    XCTAssertNotNil(parse("$[?(@.key<=42)]"))
    XCTAssertNil(parse("$[?(@.key='value')]"))
    XCTAssertNotNil(parse("$[?(@.key*2==100)]"))
    XCTAssertNotNil(parse("$[?(!(@.key==42))]"))
    XCTAssertNil(parse("$[?(!(@.d==[\"v1\",\"v2\"]) || (@.d == true))]"))
    XCTAssertNotNil(parse("$[?(!(@.key<42))]"))
    XCTAssertNotNil(parse("$[?(!@.key)]"))
    XCTAssertNotNil(parse("$[?(@.a.*)]"))
    XCTAssertNotNil(parse("$[?(@.key!=42)]"))
    XCTAssertNil(parse("$[?((@.d!=[\"v1\",\"v2\"]) || (@.d == true))]"))
    XCTAssertNil(parse("$[? @.name=~'/hello.*/']"))
    XCTAssertNil(parse("$[?(@.name=~'/@.pattern/')]"))
    XCTAssertNotNil(parse("$[?(@[*]>=4)]", strict: false))
    XCTAssertNotNil(parse("$.x[?(@[*]>=$.y[*])]", strict: false))
    XCTAssertNil(parse("$[?(@.key=42)]"))
    XCTAssertNotNil(parse("$[?(@.a[?(@.price>10)])]"))
    XCTAssertNotNil(parse("$[?(@.a.b==3)]"))
    XCTAssertNotNil(parse("$[?(@.a.b.c==3)]"))
    XCTAssertNotNil(parse("$[?(@.key-50==-100)]"))
    XCTAssertNotNil(parse("$[?(1==1)]"))
    XCTAssertNil(parse("$[?(@.key===42)]"))
    XCTAssertNotNil(parse("$[?(@.key)]"))
    XCTAssertNotNil(parse("$.*[?(@.key)]"))
    XCTAssertNotNil(parse("$..[?(@.id)]"))
    XCTAssertNotNil(parse("$[?(false)]"))
    XCTAssertNotNil(parse("$[?(@..child)]"))
    XCTAssertNotNil(parse("$[?(null)]"))
    XCTAssertNotNil(parse("$[?(true)]"))
    XCTAssertNotNil(parse("$[?@.key==42]"))
    XCTAssertNotNil(parse("$[?(@.key)]"))
    XCTAssertNil(parse("$.data.sum()"))
    XCTAssertNil(parse("$(key,more)"))
    XCTAssertNil(parse("$.."))
    XCTAssertNotNil(parse("$..*"))
    XCTAssertNil(parse("$.key.."))
    XCTAssertNil(parse("$[(@.length-1)]"))
    XCTAssertNotNil(parse("$[0,1]"))
    XCTAssertNotNil(parse("$[0,0]"))
    XCTAssertNotNil(parse("$['a','a']"))
    XCTAssertNotNil(parse("$[?(@.key<3),?(@.key>6)]"))
    XCTAssertNotNil(parse("$['key','another']"))
    XCTAssertNotNil(parse("$['missing','key']"))
    XCTAssertNotNil(parse("$[:]['c','d']"))
    XCTAssertNotNil(parse("$[0]['c','d']"))
    XCTAssertNotNil(parse("$.*['c','d']"))
    XCTAssertNotNil(parse("$..['c','d']"))
    XCTAssertNotNil(parse("$[4,1]"))
    XCTAssertNotNil(parse("$.*[0,:5]"))
    XCTAssertNotNil(parse("$[1:3,4]"))
    XCTAssertNotNil(parse("$[ 0 , 1 ]"))
    XCTAssertNotNil(parse("$[*,1]"))
  }
}
