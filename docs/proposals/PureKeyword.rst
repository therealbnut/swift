Introduction
============

This discusses the addition of a ``@pure`` annotation.

Essentially; a function should give predictable results based on its inputs.

From the `original discussion <https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20151214/003684.html>`_::

    Similar to @throws, you would mark a function as pure to say it will not
    cause any observable side-effects and hold referential transparency.

This document defines rules to enforce which functions can be marked as pure. The rules should be able to be verified by the compiler. Functions without the annotation are considered impure. Perhaps if an automated migration in most cases results in a ``@pure`` annotation then we could make pure the default and use an @impure keyword.

Open Questions
--------------

1) Is read-only capture sufficient?
2) Should reference types be allowed?
3) If reference types are allowed can they use memoization?

Rules for Purity
================

A function, method or closure is pure if
----------------------------------------
- all functions, methods and closures it calls are also pure.
- it only externally references let variables of pure type, let properties on those variables, and methods or computed-properties marked as pure.

Exceptions to the Rules
-----------------------

If the function is defined outside of swift it's unreasonable for swift to be able to verify it. If function defined outside swift has the right LLVM annotations then this could be an automated in some cases. It has been `suggested <https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20151221/003937.html>`_ that there could be a ``Builtin`` function to convert a non-pure function to a pure one (for use by the standard library).

Annotation
==========

A computed property can be marked as pure like this::

    @pure var test: A

A function/method/closure signature is marked as pure like this::

    (a: A, b: A -> B) @pure -> B

If the function/method/closure is only pure if an argument is pure (similar to @rethrows), then you could do this::

    (start: A, a: A -> B) @pure(b) -> B

Potentially this could be extended to allow a pure closure to be composed of other pure closures::

    func compose(a: A -> B, b: B -> C) @pure -> A @pure(a,b) -> C {
        return { b(a($0)) }
    }

Of course this doesn't preclude you from requiring some of those closures to be pure::

    func compose(a: A @pure -> B, b: B -> C) @pure -> A @pure(b) -> C {
        return { b(a($0)) }
    }

Examples
========

Trivial valid use of ``@pure``
------------------------------

These examples must all pass the rules defined in this document.

1) a variable with a pure function type::

    var myVar: Int @pure -> Int

2) a pure function::

    func myFunc(a: Int, _ b: Int) @pure -> Int {
        return a + b
    }

3) a pure closure::

    let myClosure = { (a: Int, b: Int) @pure -> Int in
        return a + b
    }

Valid uses of ``@pure`` using externals
---------------------------------------

1) a pure function using a constant external::

    let someGlobal: Int = 123
    func invalidRead() @pure -> Int {
        return someGlobal
    }


2) a pure function using an external pure function::

    func myOtherFunc(a: Int, b: Int, c: Int) @pure -> Int {
        return myFunc(a, b * c)
    }

Valid composition of ``@pure`` functions
----------------------------------------

1) a pure function returning a pure function::

    func ∘<T, U, V>(lhs: U @pure -> V, rhs: T @pure -> U) @pure -> (T @pure -> V) {
      return { lhs(rhs($0)) }
    }

2) a conditionally pure function::

    func ∘<T, U, V>(lhs: U -> V, rhs: T -> U) @pure -> (T @pure(lhs,rhs) -> V) {
      return { lhs(rhs($0)) }
    }

Valid use of ``@pure`` involving inout parameters
-------------------------------------------------

1) a pure function, with inout parameter::

    func myIncrement(inout a: Int) @pure {
        a = a + 1
    }

2) a pure method::

    struct MyStructure {
        var a: Int, b: Int
        func calculate() @pure -> Int {
           return a + b
        }
    }

3) a pure mutating method::

    extension Int {
        mutating func add(x: Int) @pure -> Void {
            self += x
        }
    }

Miscellaneous valid uses of ``@pure``
-------------------------------------

1) a function that mutates a local var::

    func sort(x: [Int]) @pure -> [Int] {
        var local = x
        local.sortInPlace { $0 < $1 }
        return x
    }

2) pure non-swift function use::

    func sqrt(x: Double) @pure -> Double {
        return Builtin.makePure(sqrt)(x)
    }

Complex, possibly valid uses of ``@pure``
-----------------------------------------

1) a function that modifies a passed reference type::

    class MyClass {
        var value: Int = 0
        func update(v: Int) @pure {
            value = value + v
        }
    }
    func update(ref: MyClass) @pure -> Int {
        ref.update(2)
        return ref.value
    }

2) a function that returns a passed reference type::

    func doNothing(a: MyClass) @pure -> MyClass {
        return a
    }

3) a function that returns a passed reference type via a value type::

    func both(a: MyClass, b: MyClass) @pure -> [MyClass] {
        return [a, b]
    }

Invalid uses of ``@pure``
-------------------------

1) Reading a global var::

    var someGlobal1: Int = 123
    func invalidRead() @pure -> Int {
        return someGlobal
    }

2) Writing a global var::

    var someGlobal2: Int = 123
    func invalidWrite(x: Int) @pure {
        someGlobal = x
    }

3) Modifying a global var::

    var someGlobal3 = MyStructure(a: 1, b: 2)
    func invalidModify(x: Int) @pure {
        someGlobal3.a = 456
    }


4) Calling a non-pure function::

    func invalidPrint(str: String) {
        print("\(str)")
    }

5) Calling a pure method on a global var::

    var someGlobal4 = MyStructure(a: 1, b: 2)
    func invalidMethod() @pure -> Int {
        return someGlobal4.calculate()
    }

6) Calling a pure method on a global var::

    let someGlobal5 = MyClass()
    func invalidMethod() @pure -> Void {
        someGlobal5.update(1)
    }

Complex, possibly invalid uses of ``@pure``
-------------------------------------------

1) Returning a newly allocated reference type::

    func invalidMethod() @pure -> MyClass {
        return MyClass()
    }

2) Returning a newly allocated reference type, wrapped in a value type::

    func invalidMethod() @pure -> [MyClass] {
        return [MyClass(), MyClass()]
    }
