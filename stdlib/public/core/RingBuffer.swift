//===----------------------------------------------------------------------===//
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

internal struct RingBuffer<Element>:
  RangeReplaceableCollection, MutableCollection, RandomAccessCollection,
  MutableCollectionAlgorithms
{
  fileprivate var _buffer: _RingBufferBuffer<Element>

  public typealias Indices = CountableRange<Int>
  public typealias Iterator = IndexingIterator<RingBuffer>
  public typealias SubSequence = ArraySlice<Element>

  public init() {
    self.init(capacity: 1)
  }

  public init(capacity: Int) {
    _buffer = _RingBufferBuffer(capacity: capacity)
  }
  init<S: Sequence>(_ sequence: S, capacity: Int, offset: Int)
    where S.Iterator.Element == Element {
    _buffer = _RingBufferBuffer(sequence, capacity: capacity, offset: offset)
  }

  public var startIndex: Int {
    return 0
  }
  public var endIndex: Int {
    return _buffer.count
  }
  public var underestimatedCount: Int {
    return _buffer.count
  }
  public var isFull: Bool {
    return _buffer.count == _buffer.capacity
  }
  public var count: Int {
    return _buffer.count
  }
  public var capacity: Int {
    return _buffer.capacity
  }

  public func reserveCapacity(_ n: Int) {
    // This does not make sense for a ring buffer
  }

  private mutating func mutableBuffer() -> _RingBufferBuffer<Element> {
    if !isKnownUniquelyReferenced(&_buffer) {
      _buffer = _RingBufferBuffer(_buffer,
                                  capacity: _buffer.capacity,
                                  offset: 0)
    }
    return _buffer
  }

  public subscript(bounds: Range<Int>) -> SubSequence {
    get { return _buffer[bounds] }
    set {
      let buffer = mutableBuffer()
      buffer[bounds] = newValue
    }
  }
  public subscript(position: Int) -> Element {
    get { return _buffer[position] }
    set {
      let buffer = mutableBuffer()
      buffer[position] = newValue
    }
  }

  public func index(after i: Int) -> Int { return i + 1 }
  public func index(before i: Int) -> Int { return i - 1 }

  public mutating func replaceSubrange<C>(
    _ subrange: Range<Index>, with newElements: C) where
    C : Collection, Element == C.Iterator.Element
  {
    let buffer = mutableBuffer()
    buffer.replaceSubrange(subrange, with: newElements)
  }

  public mutating func removeSubrange(_ bounds: Range<Int>) {
    let buffer = mutableBuffer()
    buffer.removeSubrange(bounds)
  }

  public mutating func removeAll() {
    let buffer = mutableBuffer()
    buffer.removeAll()
  }

  public mutating func append(_ newElement: Element) {
    let buffer = mutableBuffer()
    buffer.append(newElement)
  }
}

extension RingBuffer: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: Element...) {
    self.init(elements, capacity: elements.count, offset: 0)
  }
}

extension RingBuffer: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
    var output = "["
    if !isEmpty {
      output.reserveCapacity(2 + count * 3)
      output.append(self.lazy
        .map(String.init(describing:))
        .joined(separator: ", "))
    }
    output.append("]")
    return output
  }

  public var debugDescription: String {
    var output = "RingBuffer<"
    output.append(String(describing: Element.self))
    output.append(",\(capacity)>([")
    if _buffer.count > 0 {
      output.reserveCapacity(2 + count * 3)
      if _buffer.count < _buffer.capacity {
        output.append(self.lazy
          .map(String.init(describing:))
          .joined(separator: ", "))
      }
      else {
        let prefixCount = _buffer.count - _buffer._indexOffset
        output.append(_buffer[0 ..< prefixCount].lazy
          .map(String.init(describing:))
          .joined(separator: ", "))
        output.append("][")
        output.append(_buffer[prefixCount ..< _buffer.count].lazy
          .map(String.init(describing:))
          .joined(separator: ", "))
      }
    }
    output.append("])")

    return output
  }
}
