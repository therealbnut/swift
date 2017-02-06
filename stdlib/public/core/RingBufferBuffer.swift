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

internal class _RingBufferBuffer<Element>:
  RangeReplaceableCollection, MutableCollection, RandomAccessCollection,
  MutableCollectionAlgorithms
{
  // Stores up to _bufferCapacity elements into _buffer the indices start at
  // _indexOffset and wrap around.
  //
  // The notation [0,1][2,3,4] indicates an internal state of:
  //     _buffer:         [2,3,4,0,1]
  //     _indexOffset:    3      ^
  //     _bufferCapacity: 5
  //
  // If _bufferCount < _bufferCapacity then this has a few implications:
  //  * the buffer is not full
  //  * new elements will be appended to the end of the buffer (for speed)
  //  * _indexOffset must be zero (0)
  //
  // Algorithms used in this implementation aim to be O(1) in additional
  // memory usage, even at the expense of performance.

  private let _buffer: UnsafeMutablePointer<Element>
  private var _bufferCount: Int
  private let _bufferCapacity: Int
  internal var _indexOffset: Int

  public typealias Indices = CountableRange<Int>
  public typealias Iterator = IndexingIterator<_RingBufferBuffer>
  public typealias SubSequence = ArraySlice<Element>

  private func _checkIndex(_ position: Int) {
    _precondition(position <= _bufferCount + _bufferCapacity,
                  "RingBuffer index is out of range")
  }

  public required convenience init() {
    self.init(capacity: 1)
  }
  deinit {
    removeAll()
    _buffer.deallocate(capacity: _bufferCapacity)
  }

  public convenience init(capacity: Int) {
    let buffer = UnsafeMutablePointer<Element>.allocate(capacity: capacity)
    self.init(buffer: buffer, count: 0, capacity: capacity, offset: 0)
  }

  convenience init<S: Sequence>(_ sequence: S, capacity: Int, offset: Int)
    where S.Iterator.Element == Element {
    let buffer = UnsafeMutablePointer<Element>.allocate(capacity: capacity)
    var index = 0
    for element in sequence {
      precondition(index < capacity)
      buffer.advanced(by: index).initialize(to: element)
      index += 1
    }
    self.init(buffer: buffer,
              count: index,
              capacity: capacity,
              offset: offset)
  }

  private init(
    buffer: UnsafeMutablePointer<Element>,
    count: Int,
    capacity: Int,
    offset: Int)
  {
    _buffer = buffer
    _bufferCount = count
    _bufferCapacity = capacity
    _indexOffset = offset
  }

  public var startIndex: Int {
    return 0
  }
  public var endIndex: Int {
    return _bufferCount
  }
  public var underestimatedCount: Int {
    return _bufferCount
  }
  public var isFull: Bool {
    return _bufferCount == _bufferCapacity
  }
  public var count: Int {
    return _bufferCount
  }
  public var capacity: Int {
    return _bufferCapacity
  }

  public func reserveCapacity(_ n: Int) {
    // This does not make sense for a ring buffer
  }

  public subscript(bounds: Range<Int>) -> SubSequence {
    get {
      let count = _bufferCount
      _precondition(bounds.count <= count)
      _checkIndex(bounds.lowerBound)
      _checkIndex(bounds.upperBound)
      let lowerBound = _indexOffset + bounds.lowerBound
      let upperBound = _indexOffset + bounds.upperBound
      let buffer = UnsafeMutableBufferPointer(start: _buffer,
                                              count: _bufferCount)
      guard lowerBound < count else {
        return SubSequence(buffer[(lowerBound-count) ..< (upperBound-count)])
      }
      guard upperBound > count else {
        return SubSequence(buffer[lowerBound ..< upperBound])
      }
      let lhs = buffer[lowerBound ..< count]
      let rhs = buffer[0 ..< (upperBound - count)]
      return SubSequence([lhs, rhs].joined())
    }
    set {
      replaceSubrange(bounds, with: newValue)
    }
  }
  public subscript(position: Int) -> Element {
    get {
      _checkIndex(position)
      let index = (_indexOffset + position) % _bufferCount
      return _buffer[index]
    }
    set {
      _checkIndex(position)
      let index = (_indexOffset + position) % _bufferCount
      _buffer[index] = newValue
    }
  }

  public func index(after i: Int) -> Int {
    return i + 1
  }
  public func index(before i: Int) -> Int {
    return i - 1
  }

  public func replaceSubrange<C>(
    _ subrange: Range<Index>, with newElements: C) where
    C : Collection, Element == C.Iterator.Element
  {
    guard !newElements.isEmpty else {
      removeSubrange(subrange)
      return
    }
    guard !isEmpty else {
      _precondition(subrange.lowerBound == 0)
      for element in newElements { append(element) }
      return
    }

    let count = _bufferCount

    // FIXME: Is there a better way to do this
    // it's potentially O(n) in newElements, and has an unsafe cast
    let newCount = Int(newElements.count.toIntMax())
    // the change in self.count after inserting the elements
    let offsMin = -subrange.count, offsMax = _bufferCapacity - count
    let offset = Swift.max(offsMin, Swift.min(newCount-subrange.count, offsMax))
    var suffix = newElements.makeIterator()

    // equivalent of suffix(suffixCount), which can't be used as it uses a
    // ring buffer, this is also O(1) in memory.
    let suffixCount = Swift.max(0, offset) + subrange.count
    for _ in 0 ..< Swift.max(0, newCount-suffixCount) {
      _ = suffix.next()
    }

    // If the total number of elements doesn't increase only elements in
    // subrange need to be modified.
    // We can replace the elements of subrange, then remove excess subrange
    // elements.
    if offset <= 0 {
      if !subrange.isEmpty {
        var index = subrange.lowerBound
        while let element = suffix.next() {
          assert(index != subrange.upperBound)
          self[index] = element
          index += 1
        }
      }
      removeSubrange((subrange.upperBound+offset) ..< subrange.upperBound)
    }
    // If the total number of elements increases:
    //  1. move elements to the end as needed, or until the buffer is big enough
    //  2. insert the new elements into subrange and the new buffer
    else {
      _precondition(count < _bufferCapacity)
      _precondition(_indexOffset == 0)
      // Copy elements to the end, until there's room for newElements
      for index in Swift.max(0, count-offset) ..< count {
        _buffer.advanced(by: _bufferCount).initialize(to: _buffer[index])
        _bufferCount += 1
      }
      let range = subrange.lowerBound ..< (subrange.upperBound + offset)
      var index = range.lowerBound
      while index < count, let element = suffix.next() {
        _buffer[index] = element
        index += 1
      }
      while let element = suffix.next() {
        assert(index != count + offset)
        _buffer.advanced(by: index).initialize(to: element)
        index += 1
      }
      _bufferCount = count + offset
    }
  }

  public func removeSubrange(_ bounds: Range<Int>) {
    let count = _bufferCount
    _precondition(bounds.count <= count)
    _checkIndex(bounds.lowerBound)
    _checkIndex(bounds.upperBound)
    guard bounds.lowerBound < bounds.upperBound else {
      return
    }
    guard bounds.count < count else {
      removeAll()
      return
    }

    let newCount = count - bounds.count

    var lowerBound = _indexOffset + bounds.lowerBound
    var upperBound = _indexOffset + bounds.upperBound
    if lowerBound >= _bufferCapacity {
      lowerBound -= _bufferCapacity
      upperBound -= _bufferCapacity
    }

    if _indexOffset == 0 {
      for i in 0 ..< (newCount - bounds.lowerBound) {
        _buffer[bounds.lowerBound + i] = _buffer[bounds.upperBound + i]
      }
    }
    else {
      for i in bounds.lowerBound ..< newCount {
        let from = (_indexOffset + i + bounds.count) % _bufferCapacity
        let to = (_indexOffset + i) % _bufferCapacity
        _buffer[to] = _buffer[from]
      }
      var buffer = UnsafeMutableBufferPointer(start: _buffer,
                                              count: _bufferCount)
      buffer.rotate(shiftingToStart: _indexOffset)
    }

    for i in newCount ..< count {
      _buffer.advanced(by: i).deinitialize()
    }
    _indexOffset = 0
    _bufferCount = newCount
  }

  public func removeAll() {
    for i in 0 ..< _bufferCount {
      _buffer.advanced(by: (_indexOffset + i) % _bufferCapacity).deinitialize()
    }
    _bufferCount = 0
    _indexOffset = 0
  }

  public func append(_ newElement: Element) {
    if _bufferCount < _bufferCapacity {
      _buffer.advanced(by: _bufferCount).initialize(to: newElement)
      _bufferCount += 1
    }
    else {
      _buffer[_indexOffset] = newElement
      _indexOffset = (_indexOffset + 1) % _bufferCapacity
    }
  }
}
