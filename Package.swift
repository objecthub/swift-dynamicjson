// swift-tools-version:5.7
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
    .macOS(.v13),
    .iOS(.v16),
    .tvOS(.v16),
    .watchOS(.v9)
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
        "ComplianceTests/JSONPatch/README.md",
        "ComplianceTests/JSONPatch/README-BIG",
        "ComplianceTests/JSONPatch/bigexample1.json",
        "ComplianceTests/JSONPatch/bigexample2.json",
        "ComplianceTests/JSONPatch/bigpatch.json",
        "ComplianceTests/JSONPatch/debug.json",
        "ComplianceTests/JSONPatch/spec_tests.json",
        "ComplianceTests/JSONPatch/tests.json",
        "ComplianceTests/JSONPath/LICENSE.txt",
        "ComplianceTests/JSONPath/NOTICE.txt",
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
        "ComplianceTests/JSONPath/ws_slice.json",
        "ComplianceTests/JSONSchema/LICENSE",
        "ComplianceTests/JSONSchema/2020-12/meta/applicator",
        "ComplianceTests/JSONSchema/2020-12/meta/content",
        "ComplianceTests/JSONSchema/2020-12/meta/core",
        "ComplianceTests/JSONSchema/2020-12/meta/format-annotation",
        "ComplianceTests/JSONSchema/2020-12/meta/meta-data",
        "ComplianceTests/JSONSchema/2020-12/meta/unevaluated",
        "ComplianceTests/JSONSchema/2020-12/meta/validation",
        "ComplianceTests/JSONSchema/2020-12/schema",
        "ComplianceTests/JSONSchema/remotes/different-id-ref-string.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/baseUriChange/folderInteger.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/baseUriChangeFolder/folderInteger.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/baseUriChangeFolderInSubschema/folderInteger.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/detached-dynamicref.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/detached-ref.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/extendible-dynamic-ref.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/format-assertion-false.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/format-assertion-true.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/integer.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/locationIndependentIdentifier.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/metaschema-no-validation.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/metaschema-optional-vocabulary.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/name-defs.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/nested/foo-ref-string.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/nested/string.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/prefixItems.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/ref-and-defs.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/subSchemas.json",
        "ComplianceTests/JSONSchema/remotes/draft2020-12/tree.json",
        "ComplianceTests/JSONSchema/remotes/nested-absolute-ref-to-string.json",
        "ComplianceTests/JSONSchema/remotes/urn-ref-string.json",
        "ComplianceTests/JSONSchema/tests/additionalProperties.json",
        "ComplianceTests/JSONSchema/tests/allOf.json",
        "ComplianceTests/JSONSchema/tests/anchor.json",
        "ComplianceTests/JSONSchema/tests/anyOf.json",
        "ComplianceTests/JSONSchema/tests/boolean_schema.json",
        "ComplianceTests/JSONSchema/tests/const.json",
        "ComplianceTests/JSONSchema/tests/contains.json",
        "ComplianceTests/JSONSchema/tests/content.json",
        "ComplianceTests/JSONSchema/tests/debug.json",
        "ComplianceTests/JSONSchema/tests/default.json",
        "ComplianceTests/JSONSchema/tests/defs.json",
        "ComplianceTests/JSONSchema/tests/dependentRequired.json",
        "ComplianceTests/JSONSchema/tests/dependentSchemas.json",
        "ComplianceTests/JSONSchema/tests/dynamicRef.json",
        "ComplianceTests/JSONSchema/tests/enum.json",
        "ComplianceTests/JSONSchema/tests/exclusiveMaximum.json",
        "ComplianceTests/JSONSchema/tests/exclusiveMinimum.json",
        "ComplianceTests/JSONSchema/tests/format.json",
        "ComplianceTests/JSONSchema/tests/id.json",
        "ComplianceTests/JSONSchema/tests/if-then-else.json",
        "ComplianceTests/JSONSchema/tests/infinite-loop-detection.json",
        "ComplianceTests/JSONSchema/tests/items.json",
        "ComplianceTests/JSONSchema/tests/maxContains.json",
        "ComplianceTests/JSONSchema/tests/maximum.json",
        "ComplianceTests/JSONSchema/tests/maxItems.json",
        "ComplianceTests/JSONSchema/tests/maxLength.json",
        "ComplianceTests/JSONSchema/tests/maxProperties.json",
        "ComplianceTests/JSONSchema/tests/minContains.json",
        "ComplianceTests/JSONSchema/tests/minimum.json",
        "ComplianceTests/JSONSchema/tests/minItems.json",
        "ComplianceTests/JSONSchema/tests/minLength.json",
        "ComplianceTests/JSONSchema/tests/minProperties.json",
        "ComplianceTests/JSONSchema/tests/multipleOf.json",
        "ComplianceTests/JSONSchema/tests/not.json",
        "ComplianceTests/JSONSchema/tests/oneOf.json",
        "ComplianceTests/JSONSchema/tests/optional/anchor.json",
        "ComplianceTests/JSONSchema/tests/optional/bignum.json",
        "ComplianceTests/JSONSchema/tests/optional/cross-draft.json",
        "ComplianceTests/JSONSchema/tests/optional/dependencies-compatibility.json",
        "ComplianceTests/JSONSchema/tests/optional/ecmascript-regex.json",
        "ComplianceTests/JSONSchema/tests/optional/float-overflow.json",
        "ComplianceTests/JSONSchema/tests/optional/format-assertion.json",
        "ComplianceTests/JSONSchema/tests/optional/format/date-time.json",
        "ComplianceTests/JSONSchema/tests/optional/format/date.json",
        "ComplianceTests/JSONSchema/tests/optional/format/duration.json",
        "ComplianceTests/JSONSchema/tests/optional/format/email.json",
        "ComplianceTests/JSONSchema/tests/optional/format/hostname.json",
        "ComplianceTests/JSONSchema/tests/optional/format/idn-email.json",
        "ComplianceTests/JSONSchema/tests/optional/format/idn-hostname.json",
        "ComplianceTests/JSONSchema/tests/optional/format/ipv4.json",
        "ComplianceTests/JSONSchema/tests/optional/format/ipv6.json",
        "ComplianceTests/JSONSchema/tests/optional/format/iri-reference.json",
        "ComplianceTests/JSONSchema/tests/optional/format/iri.json",
        "ComplianceTests/JSONSchema/tests/optional/format/json-pointer.json",
        "ComplianceTests/JSONSchema/tests/optional/format/regex.json",
        "ComplianceTests/JSONSchema/tests/optional/format/relative-json-pointer.json",
        "ComplianceTests/JSONSchema/tests/optional/format/time.json",
        "ComplianceTests/JSONSchema/tests/optional/format/unknown.json",
        "ComplianceTests/JSONSchema/tests/optional/format/uri-reference.json",
        "ComplianceTests/JSONSchema/tests/optional/format/uri-template.json",
        "ComplianceTests/JSONSchema/tests/optional/format/uri.json",
        "ComplianceTests/JSONSchema/tests/optional/format/uuid.json",
        "ComplianceTests/JSONSchema/tests/optional/id.json",
        "ComplianceTests/JSONSchema/tests/optional/no-schema.json",
        "ComplianceTests/JSONSchema/tests/optional/non-bmp-regex.json",
        "ComplianceTests/JSONSchema/tests/optional/refOfUnknownKeyword.json",
        "ComplianceTests/JSONSchema/tests/optional/unknownKeyword.json",
        "ComplianceTests/JSONSchema/tests/pattern.json",
        "ComplianceTests/JSONSchema/tests/patternProperties.json",
        "ComplianceTests/JSONSchema/tests/prefixItems.json",
        "ComplianceTests/JSONSchema/tests/properties.json",
        "ComplianceTests/JSONSchema/tests/propertyNames.json",
        "ComplianceTests/JSONSchema/tests/ref.json",
        "ComplianceTests/JSONSchema/tests/refRemote.json",
        "ComplianceTests/JSONSchema/tests/required.json",
        "ComplianceTests/JSONSchema/tests/type.json",
        "ComplianceTests/JSONSchema/tests/unevaluatedItems.json",
        "ComplianceTests/JSONSchema/tests/unevaluatedProperties.json",
        "ComplianceTests/JSONSchema/tests/uniqueItems.json",
        "ComplianceTests/JSONSchema/tests/vocabulary.json"
      ])
  ],
  
  // Required Swift language version.
  swiftLanguageVersions: [.v5]
)
