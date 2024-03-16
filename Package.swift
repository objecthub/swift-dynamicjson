// swift-tools-version:5.6
//
//  Package.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 13/02/2024.
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

import PackageDescription

let package = Package(
  name: "DynamicJSON",
  
  platforms: [
    .macOS(.v11),
    .iOS(.v15)
  ],
  
  // Products define the executables and libraries produced by a package, and make them visible
  // to other packages.
  products: [
    .library(name: "DynamicJSON", targets: ["DynamicJSON"]),
    // .executable(name: "DynamicJSONTool", targets: ["DynamicJSONTool"])
  ],
  
  // Dependencies declare other packages that this package depends on.
  // e.g. `.package(url: /* package url */, from: "1.0.0"),`
  dependencies: [
    // .package(url: "https://github.com/objecthub/swift-markdownkit.git", from: "1.1.7")
  ],
  
  // Targets are the basic building blocks of a package. A target can define a module or
  // a test suite. Targets can depend on other targets in this package, and on products
  // in packages which this package depends on.
  targets: [
    .target(
      name: "DynamicJSON",
      dependencies: [
        // .product(name: "MarkdownKit", package: "swift-markdownkit")
      ],
      exclude: [
        "DynamicJSON.h",
        "DynamicJSON.docc"
      ]),
    .executableTarget(
      name: "JSONPathTool",
      dependencies: [
        .target(name: "DynamicJSON")
      ],
      exclude: []),
    .testTarget(
      name: "DynamicJSONTests",
      dependencies: [
        .target(name: "DynamicJSON")
      ],
      exclude: [
        "ComplianceTests/JSONPath/NOTICE.txt",
        "ComplianceTests/JSONPath/LICENSE.txt",
        "ComplianceTests/JSONPath/basic.json",
        "ComplianceTests/JSONPath/filter.json",
        "ComplianceTests/JSONPath/fn_count.json",
        "ComplianceTests/JSONPath/fn_length.json",
        "ComplianceTests/JSONPath/fn_match.json",
        "ComplianceTests/JSONPath/fn_search.json",
        "ComplianceTests/JSONPath/fn_value.json",
        "ComplianceTests/JSONPath/index_selector.json",
        "ComplianceTests/JSONPath/name_selector.json",
        "ComplianceTests/JSONPath/slice_selector.json",
        "ComplianceTests/JSONPath/ws_filter.json",
        "ComplianceTests/JSONPath/ws_functions.json",
        "ComplianceTests/JSONPath/ws_operators.json",
        "ComplianceTests/JSONPath/ws_selectors.json",
        "ComplianceTests/JSONPath/ws_slice.json"
      ])
  ],
  
  // Required Swift language version.
  swiftLanguageVersions: [.v5]
)
