//===--- Suffix.swift ---------------------------------------------------===//
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
let suffixCount = 1024

@inline(never)
public func run_SuffixArray(_ N: Int) {
  let s = Array(repeating: 1, count: sequenceCount)
  for _ in 1...20*N {
    for _ in 1...reps {
      var result = 0
      for element in s.suffix(suffixCount) {
        result += element
      }
      CheckResults(result == suffixCount, 
        "IncorrectResults in SuffixArray: \(result) != \(suffixCount)")
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
public func run_SuffixSequence(_ N: Int) {
  let s = MySequence(buffer: Array(repeating: 1, count: sequenceCount))
  for _ in 1...20*N {
    for _ in 1...reps {
      var result = 0
      for element in s.suffix(suffixCount) {
        result += element
      }
      CheckResults(result == suffixCount, 
        "IncorrectResults in SuffixSequence: \(result) != \(suffixCount)")
    }
  }
}

@inline(never)
public func run_SuffixAnySequence(_ N: Int) {
  let s = AnySequence(buffer: Array(repeating: 1, count: sequenceCount))
  for _ in 1...20*N {
    for _ in 1...reps {
      var result = 0
      for element in s.suffix(suffixCount) {
        result += element
      }
      CheckResults(result == suffixCount, 
        "IncorrectResults in SuffixAnySequence: \(result) != \(suffixCount)")
    }
  }
}

