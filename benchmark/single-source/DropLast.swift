//===--- DropLast.swift ---------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import TestsUtils

let reps = 1
let sequenceCount = 4096
let prefixCount = 1024
let dropCount = sequenceCount - prefixCount

@inline(never)
public func run_DropLastArray(_ N: Int) {
  let s = Array(repeating: 1, count: sequenceCount)
  for _ in 1...20*N {
    for _ in 1...reps {
      var result = 0
      for element in s.dropLast(dropCount) {
        result += element
      }
      CheckResults(result == prefixCount, 
        "IncorrectResults in DropLastArray: \(result) != \(prefixCount)")
    }
  }
}

fileprivate struct MySequence<T>: Sequence {
  var buffer: [T]
  public func makeIterator() -> IndexingIterator<[T]> {
      return buffer.makeIterator()
  }
}

@inline(never)
public func run_DropLastSequence(_ N: Int) {
  let s = MySequence(buffer: Array(repeating: 1, count: sequenceCount))
  for _ in 1...20*N {
    for _ in 1...reps {
      var result = 0
      for element in s.dropLast(dropCount) {
        result += element
      }
      CheckResults(result == prefixCount, 
        "IncorrectResults in DropLastSequence: \(result) != \(prefixCount)")
    }
  }
}

@inline(never)
public func run_DropLastAnySequence(_ N: Int) {
  let s = AnySequence(buffer: Array(repeating: 1, count: sequenceCount))
  for _ in 1...20*N {
    for _ in 1...reps {
      var result = 0
      for element in s.dropLast(dropCount) {
        result += element
      }
      CheckResults(result == prefixCount, 
        "IncorrectResults in DropLastAnySequence: \(result) != \(prefixCount)")
    }
  }
}
