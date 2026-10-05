//
//  TestOutput.swift
//  DynamicJSONTests
//
//  Created by Matthias Zenger on 04/10/2026.
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

/// Makes standard output line-buffered. If standard output is not a terminal (e.g. because it
/// is piped or captured), it is block-buffered by default, and the progress messages printed
/// by the compliance tests show up out of order with the messages written by XCTest to
/// standard error, often cutting lines in half and moving them behind the test summary.
let lineBufferedOutput: Void = {
  setvbuf(stdout, nil, _IOLBF, 0)
}()
