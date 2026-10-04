//
//  JSONPatchMaker.swift
//  DynamicJSON
//
//  Created by Matthias Zenger on 10/04/2025.
//

///
/// Class `JSONPatchMaker` computes a JSON patch that transforms a source JSON value into
/// a target JSON value. It traverses both values in parallel and records the required
/// operations. The generated patches are correct, but not minimal. Subclasses can
/// override `traverse(current:source:target:)` to customize the algorithm.
///
open class JSONPatchMaker {
  private var operations: [JSONPatchOperation]
  
  /// Creates a new patch maker without any recorded operations.
  public init() {
    self.operations = []
  }
  
  /// Appends `operation` to the sequence of operations recorded by this patch maker.
  public func append(operation: JSONPatchOperation) {
    self.operations.append(operation)
  }
  
  /// Records the operations needed to transform `source` into `target`, starting at the root.
  open func traverse(source: JSON, target: JSON) {
    self.traverse(current: JSONPointer.root, source: source, target: target)
  }
  
  /// Records the operations needed to transform `source` into `target`, both located at the
  /// JSON pointer `ptr` relative to the root of the documents.
  open func traverse(current ptr: JSONPointer, source: JSON, target: JSON) {
    switch (source, target) {
      case (.null, .null):
        break
      case (.boolean(let s), .boolean(let t)) where s == t:
        break
      case (.integer(let s), .integer(let t)) where s == t:
        break
      case (.float(let s), .float(let t)) where s == t:
        break
      case (.string(let s), .string(let t)) where s == t:
        break
      case (.array(let s), .array(let t)):
        for i in s.indices {
          if i < t.count {
            self.traverse(current: ptr.select(index: i), source: s[i], target: t[i])
          } else {
            self.append(operation: .remove(ptr.select(index: t.count)))
          }
        }
        if s.count <= t.count {
          for i in s.count..<t.count {
            self.append(operation: .add(ptr.select(index: i), t[i]))
          }
        }
      case (.object(let s), .object(let t)):
        for (k, sv) in s {
          if let tv = t[k] {
            self.traverse(current: ptr.select(member: k), source: sv, target: tv)
          } else {
            self.append(operation: .remove(ptr.select(member: k)))
          }
        }
        for (k, tv) in t {
          if s[k] == nil {
            self.append(operation: .add(ptr.select(member: k), tv))
          }
        }
      default:
        self.append(operation: .replace(ptr, target))
    }
  }
  
  /// The JSON patch consisting of all operations recorded so far.
  open var jsonPatch: JSONPatch {
    return JSONPatch(operations: self.operations)
  }
}
