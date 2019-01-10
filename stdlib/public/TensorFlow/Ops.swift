//===-- Ops.swift ------------------------------------------*- swift -*-===//
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
//
// This file contains definitions of most tensor operations.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Ops and Convenience Methods
//===----------------------------------------------------------------------===//
//
// The majority of the Tensor API is implemented in terms of 'ops' that are
// partitioned out to the TensorFlow graph when the compiler runs.  These
// ops are intentially designed to reflect TensorFlow ops, but provide nicer
// Swift syntax for accessing them.  In addition to the core ops themselves,
// we also define some helper function wrappers, e.g. to make things symmetric
// and generally feel nice to use.
//
// The ops themselves are defined by the primitive #tfop(...) syntax, here are
// some examples:
//     result = #tfop("Add", lhs, rhs)
//     result = #tfop("Const", dtype: Float.self, value$tensor: 4.0)
//
// The first parameter to this syntax is the TensorFlow op name as a string.
// After that, the inputs are specified, and then attributes are specified
// with their name as the keyword argument.
//
// Inputs and outputs must be of TensorHandle, ResourceHandle, or VariantHandle
// type.  These are magic types known to the compiler.
//

infix operator ++ : AdditionPrecedence

infix operator .< : ComparisonPrecedence
infix operator .<= : ComparisonPrecedence
infix operator .>= : ComparisonPrecedence
infix operator .> : ComparisonPrecedence
infix operator .== : ComparisonPrecedence
infix operator .!= : ComparisonPrecedence

// TODO:
// - Consider explicit broadcasting for elementwise binary ops when
//   scalarization and rank getter are implemented.

//===----------------------------------------------------------------------===//
// Scalar type cast
//===----------------------------------------------------------------------===//

public extension Tensor where Scalar : Numeric {
  /// Perform an element-wise type conversion from a `Bool` tensor.
  @inlinable @inline(__always)
  init(_ other: Tensor<Bool>) {
    self = Raw.cast(other)
  }
}

//===----------------------------------------------------------------------===//
// Additive group
//===----------------------------------------------------------------------===//

extension Tensor : AdditiveArithmetic where Scalar : Numeric {
  @inlinable
  public static var zero: Tensor {
    @inline(__always)
    get {
      return Tensor(zeros: [])
    }
  }

  /// Adds two tensors and produces their sum.
  /// - Note: `+` supports broadcasting.
  @inlinable @inline(__always)
  @differentiable(
    adjoint: _adjointAdd(_:_:_:_:)
    where Scalar : Differentiable & FloatingPoint
  )
  public static func + (lhs: Tensor, rhs: Tensor) -> Tensor {
    return Raw.add(lhs, rhs)
  }

  /// Subtracts one tensor from another and produces their difference.
  /// - Note: `-` supports broadcasting.
  @inlinable @inline(__always)
  @differentiable(
    adjoint: _adjointSubtract(_:_:_:_:)
    where Scalar : Differentiable & FloatingPoint
  )
  public static func - (lhs: Tensor, rhs: Tensor) -> Tensor {
    return Raw.sub(lhs, rhs)
  }
}

//===----------------------------------------------------------------------===//
// Vector space
//===----------------------------------------------------------------------===//

extension Tensor : VectorNumeric where Scalar : Numeric {
  /// Multiplies the scalar with every scalar of the tensor and produces the
  /// product.
  @inlinable @inline(__always)
  public static func * (lhs: Scalar, rhs: Tensor) -> Tensor {
    return Tensor(lhs) * rhs
  }
}

extension Tensor : ShapedVectorNumeric where Scalar : Numeric {}

extension Tensor : Differentiable
  where Scalar : Differentiable & FloatingPoint
{
  public typealias TangentVector = Tensor
  public typealias CotangentVector = Tensor
  @inlinable @inline(__always)
  public func tangentVector(from cotangent: CotangentVector) -> TangentVector {
    return cotangent
  }
}

//===----------------------------------------------------------------------===//
// Additional element-wise operators
//===----------------------------------------------------------------------===//

public extension Tensor where Scalar : Numeric {
  /// Adds the scalar to every scalar of the tensor and produces the sum.
  @inlinable @inline(__always)
  static func + (lhs: Scalar, rhs: Tensor) -> Tensor {
    return Tensor(lhs) + rhs
  }

  /// Adds the scalar to every scalar of the tensor and produces the sum.
  @inlinable @inline(__always)
  static func + (lhs: Tensor, rhs: Scalar) -> Tensor {
    return lhs + Tensor(rhs)
  }

  /// Subtracts the scalar from every scalar of the tensor and produces the
  /// difference.
  @inlinable @inline(__always)
  static func - (lhs: Scalar, rhs: Tensor) -> Tensor {
    return Tensor(lhs) - rhs
  }

  /// Subtracts the scalar from every scalar of the tensor and produces the
  /// difference.
  @inlinable @inline(__always)
  static func - (lhs: Tensor, rhs: Scalar) -> Tensor {
    return lhs - Tensor(rhs)
  }

  /// Adds two tensors and stores the result in the left-hand-side variable.
  /// - Note: `+=` supports broadcasting.
  @inlinable @inline(__always)
  static func += (lhs: inout Tensor, rhs: Tensor) {
    lhs = lhs + rhs
  }

  /// Adds the scalar to every scalar of the tensor and stores the result in the
  /// left-hand-side variable.
  @inlinable @inline(__always)
  static func += (lhs: inout Tensor, rhs: Scalar) {
    lhs = lhs + rhs
  }

  /// Subtracts the second tensor from the first and stores the result in the
  /// left-hand-side variable.
  /// - Note: `-=` supports broadcasting.
  @inlinable @inline(__always)
  static func -= (lhs: inout Tensor, rhs: Tensor) {
    lhs = lhs - rhs
  }

  /// Subtracts the scalar from every scalar of the tensor and stores the result
  /// in the left-hand-side variable.
  @inlinable @inline(__always)
  static func -= (lhs: inout Tensor, rhs: Scalar) {
    lhs = lhs - rhs
  }

  /// Multiplies two tensors and produces their product.
  /// - Note: `*` supports broadcasting.
  @inlinable @inline(__always)
  @differentiable(
    adjoint: _adjointMultiply(_:_:_:_:)
    where Scalar : Differentiable & FloatingPoint
  )
  static func * (lhs: Tensor, rhs: Tensor) -> Tensor {
    return Raw.mul(lhs, rhs)
  }

  /// Multiplies the scalar with every scalar of the tensor and produces the
  /// product.
  @inlinable @inline(__always)
  static func * (lhs: Tensor, rhs: Scalar) -> Tensor {
    return lhs * Tensor(rhs)
  }

  /// Multiplies two tensors and stores the result in the left-hand-side
  /// variable.
  /// - Note: `*=` supports broadcasting.
  @inlinable @inline(__always)
  static func *= (lhs: inout Tensor, rhs: Tensor) {
    lhs = lhs * rhs
  }

  @inlinable @inline(__always)
  static func *= (lhs: inout Tensor, rhs: Scalar) {
    lhs = lhs * rhs
  }

  /// Returns the quotient of dividing the first tensor by the second.
  /// - Note: `/` supports broadcasting.
  @inlinable @inline(__always)
  @differentiable(
    adjoint: _adjointDivide(_:_:_:_:)
    where Scalar : Differentiable & FloatingPoint
  )
  static func / (lhs: Tensor, rhs: Tensor) -> Tensor {
    return Raw.div(lhs, rhs)
  }

  /// Returns the quotient of dividing the scalar by the tensor, broadcasting
  /// the scalar.
  @inlinable @inline(__always)
  static func / (lhs: Scalar, rhs: Tensor) -> Tensor {
    return Tensor(lhs) / rhs
  }

  /// Returns the quotient of dividing the tensor by the scalar, broadcasting
  /// the scalar.
  @inlinable @inline(__always)
  static func / (lhs: Tensor, rhs: Scalar) -> Tensor {
    return lhs / Tensor(rhs)
  }

  /// Divides the first tensor by the second and stores the quotient in the
  /// left-hand-side variable.
  @inlinable @inline(__always)
  static func /= (lhs: inout Tensor, rhs: Tensor) {
    lhs = lhs / rhs
  }

  /// Divides the tensor by the scalar, broadcasting the scalar, and stores the
  /// quotient in the left-hand-side variable.
  @inlinable @inline(__always)
  static func /= (lhs: inout Tensor, rhs: Scalar) {
    lhs = lhs / rhs
  }

  /// Returns the remainder of dividing the first tensor by the second.
  /// - Note: `%` supports broadcasting.
  @inlinable @inline(__always)
  static func % (lhs: Tensor, rhs: Tensor) -> Tensor {
    return Raw.mod(lhs, rhs)
  }

  /// Returns the remainder of dividing the tensor by the scalar, broadcasting
  /// the scalar.
  @inlinable @inline(__always)
  static func % (lhs: Tensor, rhs: Scalar) -> Tensor {
    return lhs % Tensor(rhs)
  }

  /// Returns the remainder of dividing the scalar by the tensor, broadcasting
  /// the scalar.
  @inlinable @inline(__always)
  static func % (lhs: Scalar, rhs: Tensor) -> Tensor {
    return Tensor(lhs) % rhs
  }

  /// Divides the first tensor by the second and stores the remainder in the
  /// left-hand-side variable.
  @inlinable @inline(__always)
  static func %= (lhs: inout Tensor, rhs: Tensor) {
    lhs = lhs % rhs
  }

  /// Divides the tensor by the scalar and stores the remainder in the
  /// left-hand-side variable.
  @inlinable @inline(__always)
  static func %= (lhs: inout Tensor, rhs: Scalar) {
    lhs = lhs % rhs
  }
}

//===----------------------------------------------------------------------===//
// Linear algebra
//===----------------------------------------------------------------------===//

/// Performs matrix multiplication with another tensor and produces the
/// result.
@inlinable @inline(__always)
@differentiable(
  adjoint: _adjointMatmul(_:_:_:_:)
  where Scalar : Differentiable & FloatingPoint
)
public func matmul<Scalar : Numeric>(
  _ left: Tensor<Scalar>, _ right: Tensor<Scalar>
) -> Tensor<Scalar> {
  // Default arguments specified explicitly to avoid "external declarations of
  // SILFunctions with shared visibility is not allowed" SILVerifier error in
  // "tests/AutoDiff/tensor_autodiff_runtime.swift".
  return Raw.matMul(left, right, transposeA: false, transposeB: false)
}

infix operator • : MultiplicationPrecedence

public extension Tensor where Scalar : Numeric {
  // TODO: We have to define a custom adjoint on • because AD can't yet
  // differentiate generic methods. After AD can differentiate generic methods,
  // remove the custom adjoint.

  /// Performs matrix multiplication between two tensors and produces the
  /// result.
  @inlinable @inline(__always)
  @differentiable(
    adjoint: _adjointMatmulOperator(seed:originalValue:lhs:rhs:)
    where Scalar : Differentiable & FloatingPoint
  )
  static func • (lhs: Tensor, rhs: Tensor) -> Tensor {
    return matmul(lhs, rhs)
  }
}

//===----------------------------------------------------------------------===//
// Element-wise binary comparison
//===----------------------------------------------------------------------===//

public extension Tensor where Scalar : Numeric & Comparable {
  /// Computes `lhs < rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  @inlinable @inline(__always)
  static func .< (lhs: Tensor, rhs: Tensor) -> Tensor<Bool> {
    return Raw.less(lhs, rhs)
  }

  /// Computes `lhs <= rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  @inlinable @inline(__always)
  static func .<= (lhs: Tensor, rhs: Tensor) -> Tensor<Bool> {
    return Raw.lessEqual(lhs, rhs)
  }

  /// Computes `lhs > rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  @inlinable @inline(__always)
  static func .> (lhs: Tensor, rhs: Tensor) -> Tensor<Bool> {
    return Raw.greater(lhs, rhs)
  }

  /// Computes `lhs >= rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  @inlinable @inline(__always)
  static func .>= (lhs: Tensor, rhs: Tensor) -> Tensor<Bool> {
    return Raw.greaterEqual(lhs, rhs)
  }

  /// Computes `lhs < rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  /// - Note: `.<` supports broadcasting.
  @inlinable @inline(__always)
  static func .< (lhs: Scalar, rhs: Tensor) -> Tensor<Bool> {
    return Raw.less(Tensor(lhs), rhs)
  }

  /// Computes `lhs <= rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  /// - Note: `.<=` supports broadcasting.
  @inlinable @inline(__always)
  static func .<= (lhs: Scalar, rhs: Tensor) -> Tensor<Bool> {
    return Raw.lessEqual(Tensor(lhs), rhs)
  }

  /// Computes `lhs > rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  /// - Note: `.>` supports broadcasting.
  @inlinable @inline(__always)
  static func .> (lhs: Scalar, rhs: Tensor) -> Tensor<Bool> {
    return Raw.greater(Tensor(lhs), rhs)
  }

  /// Computes `lhs >= rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  /// - Note: `.>=` supports broadcasting.
  @inlinable @inline(__always)
  static func .>= (lhs: Scalar, rhs: Tensor) -> Tensor<Bool> {
    return Raw.greaterEqual(Tensor(lhs), rhs)
  }

  /// Computes `lhs < rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  /// - Note: `.<` supports broadcasting.
  @inlinable @inline(__always)
  static func .< (lhs: Tensor, rhs: Scalar) -> Tensor<Bool> {
    return Raw.less(lhs, Tensor(rhs))
  }

  /// Computes `lhs <= rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  /// - Note: `.<=` supports broadcasting.
  @inlinable @inline(__always)
  static func .<= (lhs: Tensor, rhs: Scalar) -> Tensor<Bool> {
    return Raw.lessEqual(lhs, Tensor(rhs))
  }

  /// Computes `lhs > rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  /// - Note: `.>` supports broadcasting.
  @inlinable @inline(__always)
  static func .> (lhs: Tensor, rhs: Scalar) -> Tensor<Bool> {
    return Raw.greater(lhs, Tensor(rhs))
  }

  /// Computes `lhs >= rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  /// - Note: `.>=` supports broadcasting.
  @inlinable @inline(__always)
  static func .>= (lhs: Tensor, rhs: Scalar) -> Tensor<Bool> {
    return Raw.greaterEqual(lhs, Tensor(rhs))
  }
}

extension Tensor : Comparable where Scalar : Numeric & Comparable {
  /// Returns a Boolean value indicating whether the value of the first argument
  /// is lexicographically less than that of the second argument.
  @inlinable @inline(__always)
  public static func < (lhs: Tensor, rhs: Tensor) -> Bool {
    return (lhs .< rhs).all()
  }

  /// Returns a Boolean value indicating whether the value of the first argument
  /// is lexicographically less than or equal to that of the second argument.
  @inlinable @inline(__always)
  public static func <= (lhs: Tensor, rhs: Tensor) -> Bool {
    return (lhs .<= rhs).all()
  }

  /// Returns a Boolean value indicating whether the value of the first argument
  /// is lexicographically greater than that of the second argument.
  @inlinable @inline(__always)
  public static func > (lhs: Tensor, rhs: Tensor) -> Bool {
    return (lhs .> rhs).all()
  }

  /// Returns a Boolean value indicating whether the value of the first argument
  /// is lexicographically greater than or equal to that of the second argument.
  @inlinable @inline(__always)
  public static func >= (lhs: Tensor, rhs: Tensor) -> Bool {
    return (lhs .>= rhs).all()
  }
}

public extension Tensor where Scalar : Numeric & Comparable {
  /// Returns a Boolean value indicating whether the value of the first argument
  /// is lexicographically less than that of the second argument.
  @inlinable @inline(__always)
  static func < (lhs: Tensor, rhs: Scalar) -> Bool {
    return (lhs .< rhs).all()
  }

  /// Returns a Boolean value indicating whether the value of the first argument
  /// is lexicographically less than or equal to that of the second argument.
  @inlinable @inline(__always)
  static func <= (lhs: Tensor, rhs: Scalar) -> Bool {
    return (lhs .<= rhs).all()
  }

  /// Returns a Boolean value indicating whether the value of the first argument
  /// is lexicographically greater than that of the second argument.
  @inlinable @inline(__always)
  static func > (lhs: Tensor, rhs: Scalar) -> Bool {
    return (lhs .> rhs).all()
  }

  /// Returns a Boolean value indicating whether the value of the first argument
  /// is lexicographically greater than or equal to that of the second argument.
  @inlinable @inline(__always)
  static func >= (lhs: Tensor, rhs: Scalar) -> Bool {
    return (lhs .>= rhs).all()
  }
}

public extension Tensor where Scalar : Equatable {
  /// Computes `lhs != rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  /// - Note: `.==` supports broadcasting.
  @inlinable @inline(__always)
  static func .==(lhs: Tensor, rhs: Tensor) -> Tensor<Bool> {
    return Raw.equal(lhs, rhs)
  }

  /// Computes `lhs != rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  /// - Note: `.!=` supports broadcasting.
  @inlinable @inline(__always)
  static func .!=(lhs: Tensor, rhs: Tensor) -> Tensor<Bool> {
    return Raw.notEqual(lhs, rhs)
  }

  /// Computes `lhs == rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  /// - Note: `.==` supports broadcasting.
  @inlinable @inline(__always)
  static func .==(lhs: Scalar, rhs: Tensor) -> Tensor<Bool> {
    return Tensor(lhs) .== rhs
  }

  /// Computes `lhs != rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  /// - Note: `.!=` supports broadcasting.
  @inlinable @inline(__always)
  static func .!=(lhs: Scalar, rhs: Tensor) -> Tensor<Bool> {
    return Tensor(lhs) .!= rhs
  }

  /// Computes `lhs == rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  /// - Note: `.==` supports broadcasting.
  @inlinable @inline(__always)
  static func .==(lhs: Tensor, rhs: Scalar) -> Tensor<Bool> {
    return lhs .== Tensor(rhs)
  }

  /// Computes `lhs != rhs` element-wise and returns a `Tensor` of Boolean
  /// scalars.
  /// - Note: `.!=` supports broadcasting.
  @inlinable @inline(__always)
  static func .!=(lhs: Tensor, rhs: Scalar) -> Tensor<Bool> {
    return lhs .!= Tensor(rhs)
  }
}

infix operator ≈ : ComparisonPrecedence

public extension Tensor where Scalar : FloatingPoint & Equatable {
  /// Returns a `Tensor` of Boolean values indicating whether the elements of
  /// `self` are approximately equal to those of `other`.
  @inlinable @inline(__always)
  func elementsApproximatelyEqual(_ other: Tensor,
                                  tolerance: Double = 0.00001) -> Tensor<Bool> {
    return Raw.approximateEqual(self, other, tolerance: tolerance)
  }
}

public extension Tensor where Scalar == Bool {
  /// Computes `!self` element-wise.
  @inlinable @inline(__always)
  func elementsLogicalNot() -> Tensor {
    return Raw.logicalNot(self)
  }

  /// Computes `self && other` element-wise.
  /// - Note: `&&` supports broadcasting.
  @inlinable @inline(__always)
  func elementsLogicalAnd(_ other: Tensor) -> Tensor {
    return Raw.logicalAnd(self, other)
  }

  /// Computes `self && other` element-wise, broadcasting `other`.
  @inlinable @inline(__always)
  func elementsLogicalAnd(_ other: Scalar) -> Tensor {
    return elementsLogicalAnd(Tensor(other))
  }

  /// Computes `self || other` element-wise.
  @inlinable @inline(__always)
  func elementsLogicalOr(_ other: Tensor) -> Tensor {
    return Raw.logicalOr(self, other)
  }

  /// Computes `self || other` element-wise, broadcasting `other`.
  @inlinable @inline(__always)
  func elementsLogicalOr(_ other: Scalar) -> Tensor {
    return elementsLogicalOr(Tensor(other))
  }
}

//===----------------------------------------------------------------------===//
// Transforms
//===----------------------------------------------------------------------===//

public extension Tensor {
  /// Returns a transposed tensor, with dimensions permuted in the specified
  /// order.
  @inlinable @inline(__always)
  @differentiable(
    wrt: (self), adjoint: _adjointTransposed(_:_:_:)
    where Scalar : Differentiable & FloatingPoint
  )
  func transposed(
    withPermutations permutations: Tensor<Int32>
  ) -> Tensor {
    return Raw.transpose(self, perm: permutations)
  }

  /// Returns a transposed tensor, with dimensions permuted in the specified
  /// order.
  @inlinable @inline(__always)
  func transposed(withPermutations permutations: Int32...) -> Tensor {
    return transposed(withPermutations: Tensor<Int32>(permutations))
  }

  /// Returns a transposed tensor, with dimensions permuted in reverse order.
  @inlinable @inline(__always)
  func transposed() -> Tensor {
    let defaultPermutations = rankTensor - 1 - Tensor<Int32>(
      rangeFrom: 0, to: rank, stride: 1
    )
    return transposed(withPermutations: Tensor<Int32>(defaultPermutations))
  }
}

public extension Tensor {
  /// Concatenates tensors along the first dimension.
  /// - Precondition: The tensors must have the same shape, except for the
  ///   leading dimension.
  @inlinable @inline(__always)
  func concatenated(with other: Tensor) -> Tensor {
    return Raw.concatV2([self, other], axis: Tensor<Int32>(0))
  }

  /// Concatenates tensors along the specified axis.
  /// - Precondition: The tensors must have the same dimensions, except for the
  ///   specified axis.
  /// - Precondition: The axis must be in the range `-rank..<rank`.
  @inlinable @inline(__always)
  func concatenated(with other: Tensor, alongAxis axis: Int32) -> Tensor {
    return Raw.concatV2([self, other], axis: Tensor<Int32>(axis))
  }

  /// Concatenation operator.
  /// - Note: `++` is a custom operator that does not exist in Swift, but does
  ///   in Haskell/Scala. Its addition is not an insignificant language change
  ///   and may be controversial. The existence/naming of `++` will be discussed
  ///   during a later API design phase.
  @inlinable @inline(__always)
  static func ++ (lhs: Tensor, rhs: Tensor) -> Tensor {
    return lhs.concatenated(with: rhs)
  }
}

//===----------------------------------------------------------------------===//
// Element-wise math functions
//===----------------------------------------------------------------------===//

// Export Glibc/Darwin math functions. We should not require users to import
// Foundation/Darwin/Glibc in order to use scalar math functions.
//
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
@_exported import Darwin.C
#else
@_exported import Glibc
#endif
//
// FIXME(rxwei): Scoped imports are not yet supported in parseable module
// interfaces, so `@_exported import` won't work. When that becomes supported,
// switch to `@_exported import` by removing `import Darwin.C/Glibc` above and
// uncommenting the following lines. In the meantime, consider using indirect
// wrappers for each function so that random libc symbols won't be leaked to
// users' code completion.
//
// #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
// @_exported import func Darwin.C.sin
// @_exported import func Darwin.C.cos
// @_exported import func Darwin.C.tan
// @_exported import func Darwin.C.sinf
// @_exported import func Darwin.C.cosf
// @_exported import func Darwin.C.tanf
// @_exported import func Darwin.C.sinh
// @_exported import func Darwin.C.cosh
// @_exported import func Darwin.C.tanh
// @_exported import func Darwin.C.sinhf
// @_exported import func Darwin.C.coshf
// @_exported import func Darwin.C.tanhf
// @_exported import func Darwin.C.log
// @_exported import func Darwin.C.logf
// @_exported import func Darwin.C.exp
// @_exported import func Darwin.C.expf
// @_exported import func Darwin.C.pow
// @_exported import func Darwin.C.powf
// #else
// @_exported import func Glibc.sin
// @_exported import func Glibc.cos
// @_exported import func Glibc.tan
// @_exported import func Glibc.sinf
// @_exported import func Glibc.cosf
// @_exported import func Glibc.tanf
// @_exported import func Glibc.sinh
// @_exported import func Glibc.cosh
// @_exported import func Glibc.tanh
// @_exported import func Glibc.sinhf
// @_exported import func Glibc.coshf
// @_exported import func Glibc.tanhf
// @_exported import func Glibc.log
// @_exported import func Glibc.logf
// @_exported import func Glibc.exp
// @_exported import func Glibc.expf
// @_exported import func Glibc.pow
// @_exported import func Glibc.powf
// #endif

public extension Tensor where Scalar : SignedNumeric {
  /// Computes the negation of the specified tensor element-wise.
  @inlinable @inline(__always)
  @differentiable(
    adjoint: _adjointNegate(_:_:_:)
    where Scalar : Differentiable & FloatingPoint
  )
  static prefix func - (rhs: Tensor) -> Tensor {
    return Raw.neg(rhs)
  }
}

/// Computes the absolute value of the specified tensor element-wise.
@inlinable @inline(__always)
public func abs<T : SignedNumeric>(_ x: Tensor<T>) -> Tensor<T> {
  return Raw.abs(x)
}

/// Computes the natural logarithm of the specified tensor element-wise.
@inlinable @inline(__always)
@differentiable(adjoint: _adjointLog(_:_:_:) where T : Differentiable)
public func log<T : FloatingPoint>(_ x: Tensor<T>) -> Tensor<T> {
  return Raw.log(x)
}

/// Computes `sin` of the specified tensor element-wise.
@inlinable @inline(__always)
@differentiable(adjoint: _adjointSin(_:_:_:) where T : Differentiable)
public func sin<T : FloatingPoint>(_ x: Tensor<T>) -> Tensor<T> {
  return Raw.sin(x)
}

/// Computes `cos` of the specified tensor element-wise.
@inlinable @inline(__always)
@differentiable(adjoint: _adjointCos(_:_:_:) where T : Differentiable)
public func cos<T : FloatingPoint>(_ x: Tensor<T>) -> Tensor<T> {
  return Raw.cos(x)
}

/// Computes `tan` of the specified tensor element-wise.
@inlinable @inline(__always)
@differentiable(adjoint: _adjointTan(_:_:_:) where T : Differentiable)
public func tan<T : FloatingPoint>(_ x: Tensor<T>) -> Tensor<T> {
  return Raw.tan(x)
}

/// Computes `sinh` of the specified tensor element-wise.
@inlinable @inline(__always)
@differentiable(adjoint: _adjointSinh(_:_:_:) where T : Differentiable)
public func sinh<T : FloatingPoint>(_ x: Tensor<T>) -> Tensor<T> {
  return Raw.sinh(x)
}

/// Computes `cosh` of the specified tensor element-wise.
@inlinable @inline(__always)
@differentiable(adjoint: _adjointCosh(_:_:_:) where T : Differentiable)
public func cosh<T : FloatingPoint>(_ x: Tensor<T>) -> Tensor<T> {
  return Raw.cosh(x)
}

/// Computes `tanh` of the specified tensor element-wise.
@inlinable @inline(__always)
@differentiable(adjoint: _adjointTanh(_:_:_:) where T : Differentiable)
public func tanh<T : FloatingPoint>(_ x: Tensor<T>) -> Tensor<T> {
  return Raw.tanh(x)
}

/// Computes the square root of the specified tensor element-wise.
@inlinable @inline(__always)
@differentiable(adjoint: _adjointSqrt(_:_:_:) where T : Differentiable)
public func sqrt<T : FloatingPoint>(_ x: Tensor<T>) -> Tensor<T> {
  return Raw.sqrt(x)
}

/// Computes the inverse square root of the specified tensor element-wise.
@inlinable @inline(__always)
@differentiable(adjoint: _adjointRsqrt(_:_:_:) where T : Differentiable)
public func rsqrt<T : FloatingPoint>(_ x: Tensor<T>) -> Tensor<T> {
  return Raw.rsqrt(x)
}

/// Computes `exp` of the specified tensor element-wise.
@inlinable @inline(__always)
@differentiable(adjoint: _adjointExp(_:_:_:) where T : Differentiable)
public func exp<T : FloatingPoint>(_ x: Tensor<T>) -> Tensor<T> {
  return Raw.exp(x)
}

/// Computes the ceiling of the specified tensor element-wise.
@inlinable @inline(__always)
@differentiable(adjoint: _adjointCeil(_:_:_:) where T : Differentiable)
public func ceil<T : FloatingPoint>(_ x: Tensor<T>) -> Tensor<T> {
  return Raw.ceil(x)
}

/// Computes the floor of the specified tensor element-wise.
@inlinable @inline(__always)
@differentiable(adjoint: _adjointFloor(_:_:_:) where T : Differentiable)
public func floor<T : FloatingPoint>(_ x: Tensor<T>) -> Tensor<T> {
  return Raw.floor(x)
}

/// Computes the power of the first tensor to the second tensor.
@inlinable @inline(__always)
@differentiable(adjoint: _adjointPow(_:_:_:_:) where T : Differentiable)
public func pow<T>(_ lhs: Tensor<T>, _ rhs: Tensor<T>) -> Tensor<T>
  where T : FloatingPoint {
  return Raw.pow(lhs, rhs)
}

/// Computes the power of the scalar to the tensor, broadcasting the scalar.
@inlinable @inline(__always)
public func pow<T>(_ lhs: T, _ rhs: Tensor<T>) -> Tensor<T>
  where T : FloatingPoint {
  return pow(Tensor(lhs), rhs)
}

/// Computes the power of the tensor to the scalar, broadcasting the scalar.
@inlinable @inline(__always)
public func pow<T>(_ lhs: Tensor<T>, _ rhs: T) -> Tensor<T>
  where T : FloatingPoint {
  return pow(lhs, Tensor(rhs))
}

/// Computes the element-wise maximum of two tensors.
/// - Note: `max` supports broadcasting.
@inlinable @inline(__always)
@differentiable(
  adjoint: _adjointMinMax(_:_:_:_:)
  where T : Differentiable & FloatingPoint
)
public func max<T>(_ lhs: Tensor<T>, _ rhs: Tensor<T>) -> Tensor<T>
  where T : Numeric & Comparable {
  return Raw.maximum(lhs, rhs)
}

/// Computes the element-wise maximum of the scalar and the tensor, broadcasting
/// the scalar.
@inlinable @inline(__always)
public func max<T>(_ lhs: T, _ rhs: Tensor<T>) -> Tensor<T>
  where T : Numeric & Comparable {
  return max(Tensor(lhs), rhs)
}

/// Computes the element-wise maximum of the scalar and the tensor, broadcasting
/// the scalar.
@inlinable @inline(__always)
public func max<T>(_ lhs: Tensor<T>, _ rhs: T) -> Tensor<T>
  where T : Numeric & Comparable {
  return max(lhs, Tensor(rhs))
}

/// Computes the element-wise minimum of two tensors.
/// - Note: `min` supports broadcasting.
@inlinable @inline(__always)
@differentiable(
  adjoint: _adjointMinMax(_:_:_:_:)
  where T : Differentiable & FloatingPoint
)
public func min<T>(_ lhs: Tensor<T>, _ rhs: Tensor<T>) -> Tensor<T>
  where T : Numeric & Comparable {
  return Raw.minimum(lhs, rhs)
}

/// Computes the element-wise minimum of the scalar and the tensor, broadcasting
/// the scalar.
@inlinable @inline(__always)
public func min<T>(_ lhs: T, _ rhs: Tensor<T>) -> Tensor<T>
  where T : Numeric & Comparable {
  return min(Tensor(lhs), rhs)
}

/// Computes the element-wise minimum of the scalar and the tensor, broadcasting
/// the scalar.
@inlinable @inline(__always)
public func min<T>(_ lhs: Tensor<T>, _ rhs: T) -> Tensor<T>
  where T : Numeric & Comparable {
  return min(lhs, Tensor(rhs))
}

/// Computes the square of the tensor.
public extension Tensor where Scalar : Numeric {
  @inlinable @inline(__always)
  func squared() -> Tensor {
    return Raw.square(self)
  }
}

//===----------------------------------------------------------------------===//
// Non-elementwise math functions
//===----------------------------------------------------------------------===//

/// Computes the log-softmax of the specified tensor element-wise.
@inlinable @inline(__always)
public func logSoftmax<T : FloatingPoint>(_ x: Tensor<T>) -> Tensor<T> {
  return Raw.logSoftmax(logits: x)
}

//===----------------------------------------------------------------------===//
// Selection
//===----------------------------------------------------------------------===//

public extension Tensor where Scalar == Bool {
  /// Returns a new tensor containing elements from either `left` or `right`,
  /// depending on the elements of `self`.
  ///
  /// `self` acts as a amsk that chooses, based on the value at each scalar,
  ///  whether the corresponding scalar in the output should be taken from
  /// `left` (if `true`) or `right` (if `false`).
  ///
  /// - Precondition: `left` and `right` must have the same shape. If
  ///   `left` and `right` are scalar, then `self` must also be scalar. If
  ///   `left` and `right` have rank greater than or equal to 1, then `self`
  ///   must be either have the same shape as `left` or be a 1-D `Tensor` such
  ///   that `self.scalarCount == left[0]`.
  @inlinable @inline(__always)
  func selecting<T>(_ left: Tensor<T>, _ right: Tensor<T>) -> Tensor<T> {
    return Raw.select(condition: self, t: left, e: right)
  }

  // FIXME: "Select" is non-broadcasting: `left` and `right` are required to
  // have the same shapes. An explicit broadcast must be added.
  @inlinable @inline(__always)
  func selecting<T>(_ left: T, _ right: Tensor<T>) -> Tensor<T> {
    return selecting(Tensor<T>(left), right)
  }

  // FIXME: "Select" is non-broadcasting: `left` and `right` are required to
  // have the same shapes. An explicit broadcast must be added.
  @inlinable @inline(__always)
  func selecting<T>(_ left: Tensor<T>, _ right: T) -> Tensor<T> {
    return selecting(left, Tensor<T>(right))
  }

  // FIXME: "Select" is non-broadcasting: `left` and `right` are required to
  // have the same shapes. An explicit broadcast must be added.
  @inlinable @inline(__always)
  func selecting<T>(_ left: T, _ right: T) -> Tensor<T> {
    return selecting(Tensor<T>(left), Tensor<T>(right))
  }
}

//===----------------------------------------------------------------------===//
// Reduction
//===----------------------------------------------------------------------===//

public extension Tensor where Scalar == Bool {
  /// Returns `true` if all scalars are equal to `true`. Otherwise, returns
  /// `false`.
  // NOTE: This overload is necessary, otherwise `all()` would refer
  // to the variadic method `all(squeezingAxes:)` with zero indices.
  @inlinable @inline(__always)
  func all() -> Bool {
    let axes = Tensor<Int32>(rangeFrom: 0, to: rank, stride: 1)
    return _TFGetScalarOrDie(Raw.all(self, reductionIndices: axes).handle)
  }

  /// Returns `true` if any scalars are equal to `true`. Otherwise, returns
  /// `false`.
  // NOTE: This overload is necessary, otherwise `any()` would refer
  // to the variadic method `any(squeezingAxes:)` with zero indices.
  @inlinable @inline(__always)
  func any() -> Bool {
    let axes = Tensor<Int32>(rangeFrom: 0, to: rank, stride: 1)
    return _TFGetScalarOrDie(Raw.any(self, reductionIndices: axes).handle)
  }

  /// Performs a logical AND operation along the specified axes. The reduced
  /// dimensions are removed.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank..<rank`.
  @inlinable @inline(__always)
  func all(squeezingAxes axes: Int32...) -> Tensor {
    return Raw.all(self, reductionIndices: Tensor<Int32>(axes), keepDims: false)
  }

  /// Performs a logical AND operation along the specified axes. The reduced
  /// dimensions are removed.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank..<rank`.
  @inlinable @inline(__always)
  func any(squeezingAxes axes: Int32...) -> Tensor {
    return Raw.any(self, reductionIndices: Tensor<Int32>(axes), keepDims: false)
  }

  /// Performs a logical AND operation along the specified axes. The reduced
  /// dimensions are retained with value 1.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank..<rank`.
  @inlinable @inline(__always)
  func all(alongAxes axes: Int32...) -> Tensor {
    return Raw.all(self, reductionIndices: Tensor<Int32>(axes), keepDims: true)
  }

  /// Performs a logical OR operation along the specified axes. The reduced
  /// dimensions are retained with value 1.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank..<rank`.
  @inlinable @inline(__always)
  func any(alongAxes axes: Int32...) -> Tensor {
    return Raw.any(self, reductionIndices: Tensor<Int32>(axes), keepDims: true)
  }
}

public extension Tensor where Scalar : Numeric & Comparable {
  // NOTE: This overload is necessary, otherwise `min()` would refer
  // to the variadic method `min(squeezingAxes:)` with zero indices.
  @inlinable @inline(__always)
  func min() -> Tensor {
    let axes = Tensor<Int32>(rangeFrom: 0, to: rank, stride: 1)
    return Raw.min(self, reductionIndices: axes)
  }

  // NOTE: This overload is necessary, otherwise `max()` would refer
  // to the variadic method `max(squeezingAxes:)` with zero indices.
  @inlinable @inline(__always)
  func max() -> Tensor {
    let axes = Tensor<Int32>(rangeFrom: 0, to: rank, stride: 1)
    return Raw.max(self, reductionIndices: axes)
  }

  /// Returns the maximum values along the specified axes. The reduced
  /// dimensions are removed.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank..<rank`.
  @inlinable @inline(__always)
  func max(squeezingAxes axes: Int32...) -> Tensor {
    return Raw.max(self, reductionIndices: Tensor<Int32>(axes), keepDims: false)
  }

  /// Returns the minimum values along the specified axes. The reduced
  /// dimensions are removed.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank..<rank`.
  @inlinable @inline(__always)
  func min(squeezingAxes axes: Int32...) -> Tensor {
    return Raw.min(self, reductionIndices: Tensor<Int32>(axes), keepDims: false)
  }

  /// Returns the indices of the maximum values along the specified axes. The
  /// reduced dimensions are removed.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank..<rank`.
  @inlinable @inline(__always)
  func argmax(squeezingAxis axis: Int32) -> Tensor<Int32> {
    return Raw.argMax(self, dimension: Tensor<Int32>(axis))
  }

  /// Returns the indices of the minimum values along the specified axes. The
  /// reduced dimensions are removed.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank..<rank`.
  @inlinable @inline(__always)
  func argmin(squeezingAxis axis: Int32) -> Tensor<Int32> {
    return Raw.argMin(self, dimension: Tensor<Int32>(axis))
  }

  /// Returns the minimum along the specified axes. The reduced dimensions are
  /// retained with value 1.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank..<rank`.
  @inlinable @inline(__always)
  func min(alongAxes axes: Int32...) -> Tensor {
    return Raw.min(self, reductionIndices: Tensor<Int32>(axes), keepDims: true)
  }

  /// Returns the minimum along the specified axes. The reduced dimensions are
  /// retained with value 1.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank..<rank`.
  @inlinable @inline(__always)
  func max(alongAxes axes: Int32...) -> Tensor {
    return Raw.max(self, reductionIndices: Tensor<Int32>(axes), keepDims: true)
  }

  /// Returns the index of the maximum value of the flattened scalars.
  @inlinable @inline(__always)
  func argmax() -> Tensor<Int32> {
    return flattened().argmax(squeezingAxis: 0)
  }

  /// Returns the index of the minimum value of the flattened scalars.
  @inlinable @inline(__always)
  func argmin() -> Tensor<Int32> {
    return flattened().argmin(squeezingAxis: 0)
  }
}

public extension Tensor where Scalar : Numeric {
  // NOTE: This overload is necessary, otherwise `mean()` would refer
  // to the variadic method `mean(squeezingAxes:)` with zero indices.
  @inlinable @inline(__always)
  func mean() -> Tensor {
    let axes = Tensor<Int32>(rangeFrom: 0, to: rank, stride: 1)
    return Raw.mean(self, reductionIndices: axes)
  }

  // NOTE: This overload is necessary, otherwise `sum()` would refer
  // to the variadic method `sum(squeezingAxes:)` with zero indices.
  @inlinable @inline(__always)
  func sum() -> Tensor {
    let axes = Tensor<Int32>(rangeFrom: 0, to: rank, stride: 1)
    return Raw.sum(self, reductionIndices: axes)
  }

  // NOTE: This overload is necessary, otherwise `sum()` would refer
  // to the variadic method `sum(squeezingAxes:)` with zero indices.
  @inlinable @inline(__always)
  func product() -> Tensor {
    let axes = Tensor<Int32>(rangeFrom: 0, to: rank, stride: 1)
    return Raw.prod(self, reductionIndices: axes)
  }

  /// Returns the arithmetic mean along the specified axes. The reduced
  /// dimensions are removed.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank...rank`.
  @inlinable @inline(__always)
  func mean(squeezingAxes axes: Int32...) -> Tensor {
    return Raw.mean(self, reductionIndices: Tensor<Int32>(axes),
                    keepDims: false)
  }

  /// Returns the sum along the specified axes. The reduced dimensions are
  /// removed.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank...rank`.
  @inlinable @inline(__always)
  func sum(squeezingAxes axes: Int32...) -> Tensor {
    return Raw.sum(self, reductionIndices: Tensor<Int32>(axes), keepDims: false)
  }

  /// Returns the product along the specified axes. The reduced dimensions are
  /// removed.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank...rank`.
  @inlinable @inline(__always)
  func product(squeezingAxes axes: Int32...) -> Tensor {
    return Raw.prod(self, reductionIndices: Tensor<Int32>(axes),
                    keepDims: false)
  }

  /// Returns the arithmetic mean along the specified axes. The reduced
  /// dimensions are retained with value 1.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank..<rank`.
  @inlinable @inline(__always)
  func mean(alongAxes axes: Int32...) -> Tensor {
    return Raw.mean(self, reductionIndices: Tensor<Int32>(axes), keepDims: true)
  }

  /// Returns the sum along the specified axes. The reduced dimensions are
  /// retained with value 1.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank..<rank`.
  @inlinable @inline(__always)
  func sum(alongAxes axes: Int32...) -> Tensor {
    return Raw.sum(self, reductionIndices: Tensor<Int32>(axes), keepDims: true)
  }

  /// Returns the product along the specified axes. The reduced dimensions are
  /// retained with value 1.
  /// - Parameter axes: The dimensions to reduce.
  /// - Precondition: Each value in `axes` must be in the range `-rank..<rank`.
  @inlinable @inline(__always)
  func product(alongAxes axes: Int32...) -> Tensor {
    return Raw.prod(self, reductionIndices: Tensor<Int32>(axes), keepDims: true)
  }
}

//===----------------------------------------------------------------------===//
// Tensor properties
//===----------------------------------------------------------------------===//

public extension Tensor {
  /// The rank of the tensor, represented as a `Tensor<Int32>`.
  @inlinable
  var rankTensor: Tensor<Int32> {
    @inline(__always)
    get {
      return Raw.rank(self)
    }
  }

  /// The dimensions of the tensor, represented as a `Tensor<Int32>`.
  @inlinable
  var shapeTensor: Tensor<Int32> {
    @inline(__always)
    get {
      return Raw.shape(self)
    }
  }

  /// The number of scalars in the tensor, represented as a `Tensor<Int32>`.
  @inlinable
  var scalarCountTensor: Tensor<Int32> {
    @inline(__always)
    get {
      return Raw.size(self)
    }
  }
}

//===----------------------------------------------------------------------===//
// Broadcasting
//===----------------------------------------------------------------------===//

public extension Tensor {
  @inlinable @inline(__always)
  func broadcast(toShape shape: Tensor<Int32>) -> Tensor {
    return Raw.broadcastTo(self, shape: shape)
  }

  @inlinable @inline(__always)
  func broadcast(to shape: TensorShape) -> Tensor {
    return broadcast(toShape: Tensor<Int32>(shape.dimensions))
  }

  /// Broadcast to the same shape as the specified `Tensor`.
  /// - Precondition: The specified shape must be compatible for broadcasting.
  @inlinable @inline(__always)
  func broadcast<OtherScalar>(like other: Tensor<OtherScalar>) -> Tensor {
    return broadcast(toShape: other.shapeTensor)
  }
}

public extension Tensor where Scalar : Numeric {
  @inlinable @inline(__always)
  func unbroadcast(toShape otherShape: Tensor<Int32>) -> Tensor {
    let rankDiff = (rankTensor - otherShape.scalarCountTensor).rankLifted()
    let ones: Tensor<Int32> = Raw.fill(dims: rankDiff, value: Tensor<Int32>(1))
    let paddedShape = ones ++ otherShape
    let nonEqualIndices = paddedShape .!= shapeTensor
    let broadcastIndices = Raw.where_(nonEqualIndices).flattened()
    let unbroadcasted: Tensor = Raw.sum(
      self, reductionIndices: Tensor<Int32>(broadcastIndices), keepDims: false)
    return Raw.reshape(unbroadcasted, shape: otherShape)
  }

  @inlinable @inline(__always)
  func unbroadcast<OtherScalar>(like other: Tensor<OtherScalar>) -> Tensor {
    return unbroadcast(toShape: other.shapeTensor)
  }

  @inlinable @inline(__always)
  func unbroadcast(to shape: TensorShape) -> Tensor {
    return unbroadcast(toShape: Tensor<Int32>(shape.dimensions))
  }
}

//===----------------------------------------------------------------------===//
// Padding
//===----------------------------------------------------------------------===//

public extension Tensor where Scalar : Numeric {
  /// Returns a padded tensor according to the specified padding sizes.
  @inlinable @inline(__always)
  func padded(
    forSizes sizes: @autoclosure () -> [(before: Int32, after: Int32)],
    with value: Scalar = 0
  ) -> Tensor {
    let paddings: TensorHandle<Int32> = _TFHoistable {
      let sizes = sizes()
      return Tensor<Int32>(
        shape: [Int32(sizes.count), 2],
        scalars: sizes.flatMap { [$0.before, $0.after] }
      ).handle
    }
    return Raw.padV2(
      self,
      paddings: Tensor<Int32>(handle: _TFToAcclerator(paddings)),
      constantValues: Tensor(value))
  }
}

//===----------------------------------------------------------------------===//
// Indexing and slicing
//===----------------------------------------------------------------------===//

public extension Tensor {
  /// Access the element tensor specified by an index in the leading dimension.
  /// - Parameter index: Index of the element tensor.
  @inlinable
  subscript(index: Int32) -> Tensor {
    @inline(__always)
    get {
      // NOTE: Thought Gather exactly performs element indexing, it is an
      // allocating operation. Slice is used here instead even though the
      // implementation is more convoluted because it is non-allocating.
      // Actual performance/memory tests should be done for some empirical
      // comparison.
      // Gather implementation is below:
      // return #tfop("GatherV2", self, Tensor<Int32>(index), Tensor<Int32>(0),
      //              Tindices: Int32.self)
      let indexTensor = Tensor<Int32>(index).rankLifted()
      let remainingZeros: Tensor<Int32> = Raw.fill(
        dims: (rankTensor - 1).rankLifted(), value: Tensor<Int32>(0))
      let startIndices = indexTensor.concatenated(with: remainingZeros)

      let firstDimension: Tensor<Float> = Raw.gatherV2(
        params: Tensor<Float>(shapeTensor),
        indices: Tensor<Int32>(0),
        axis: Tensor<Int32>(0)
      )
      let boundSize = Tensor<Float>([1]) - firstDimension
      let scatterIndices: Tensor<Int32> = [[0]]
      let offset: Tensor<Int32> = Tensor<Int32>(
        Raw.scatterNd(
          indices: scatterIndices,
          updates: boundSize,
          shape: rankTensor.rankLifted()
        )
      )
      let boundSizes: Tensor<Int32> = shapeTensor + offset
      let slice: Tensor = Raw.slice(self, begin: startIndices, size: boundSizes)
      return slice.squeezingShape(at: 0)
    }
    @inline(__always)
    set {
      let left = self[0..<index]
      let right = self[index+1..<_TFGetScalarOrDie(shapeTensor[0].handle)]
      self = Raw.concatV2([left, newValue.rankLifted(), right], axis: Tensor<Int32>(0))
    }
  }

  /// Access the subdimensional tensor at the specified list of indices.
  /// - Parameter indices: List of indices.
  /// - Note: this function is more efficient than using `subscript(index:)`
  ///   multiple times because this produces a single GatherNd op (compared with
  ///   multiple Gather ops).
  @inlinable
  subscript(indices: Int32...) -> Tensor {
    @inline(__always)
    get {
      // NOTE: Rewriting this using Slice is difficult: the main challenge is in
      // constructing the "sizes" argument, which essentially is
      // `indices.shapeTensor` but with `indices.count` number of leading 1s.
      // Since GatherNd is the exact op that performs subdimensional indexing,
      // it is used here in spite of the fact it may perform allocation(?).
      // TODO: Consider more clearly distinguishing `subscript(index:)` and
      // `subscript(indices:)`, since their implementations are quite different.
      return Raw.gatherNd(params: self, indices: Tensor<Int32>(indices))
    }
  }

  /// Access the subtensor specified by a contiguous range of indices.
  /// - Parameter bounds: Contiguous range of indices.
  @inlinable
  subscript(bounds: Range<Int32>) -> Tensor {
    @inline(__always)
    get {
      // NOTE: Though `tf.slice` and `tf.strided_slice` are not easy to use
      // because they require slice bounds for every dimension, they should be
      // used because the are non-allocating. Other slice implementations (like
      // combining Gather and Range) perform allocation and should not be used
      // even though they are easier to write.

      // Let (lo, hi) represent lower and upper bounds respectively.
      // startIndices = [lo, 0, 0, ..., 0]
      // boundSizes = [hi - lo, d1, d2, ..., dn] where di = shape[i]
      // TODO: The horrendous mess of type-casting is necessary due to GPU ops
      // (Gather, ScatterNd) not accepting Int32 for particular inputs. Refactor
      // if possible.
      let lowerBound = Tensor<Int32>(bounds.lowerBound).rankLifted()
      let remainingZeros: Tensor<Int32> = Raw.fill(
        dims: (rankTensor - 1).rankLifted(), value: Tensor<Int32>(0))
      let startIndices = lowerBound.concatenated(with: remainingZeros)

      let boundSize = Tensor<Int32>(bounds.upperBound).rankLifted()
        - lowerBound - Tensor<Int32>(Tensor<Float>(shapeTensor)[0])
      let scatterIndices: Tensor<Int32> = [[0]]
      let offset: Tensor<Int32> = Tensor<Int32>(
        Raw.scatterNd(
          indices: scatterIndices,
          updates: Tensor<Float>(boundSize),
          shape: rankTensor.rankLifted()
        )
      )
      let boundSizes: Tensor<Int32> = shapeTensor + offset
      return Raw.slice(self, begin: startIndices, size: boundSizes)
    }
  }

  // TODO(danielzheng): Add strided slices? (increment by something different
  // than 1)
  // Ideas for strided slice API: it could be another subscript method, or it
  // be a top level `stride` function like Swift's `stride(from:to:by:)`.

  /// Extracts a slice from the tensor defined by lower and upper bounds for
  /// each dimension.
  ///
  /// - Parameter lowerBounds: The lower bounds at each dimension.
  /// - Parameter upperBounds: The upper bounds at each dimension.
  @inlinable @inline(__always)
  func slice(lowerBounds: [Int32], upperBounds: [Int32]) -> Tensor {
    /// TODO: Precondition `lowerBounds.count == upperBounds.count`,
    /// preferably in graph.
    let lowerBoundsTensor = Tensor<Int32>(lowerBounds)
    return Raw.slice(
      self,
      begin: lowerBoundsTensor,
      size: Tensor<Int32>(upperBounds) - lowerBoundsTensor)
  }
}

//===----------------------------------------------------------------------===//
// Normalization
//===----------------------------------------------------------------------===//

public extension Tensor where Scalar : BinaryFloatingPoint {
  /// Computes the batch normalized tensor along the specified axis.
  ///
  /// Specifically, returns `(self - mu)/(var + epsilon) * gamma + beta` where
  /// `mu` and `var` are respectively the mean and variance of `self` along
  /// `axis`.
  ///
  /// - Parameters:
  ///   - axis: The batch dimension.
  ///   - offset: The scalar offset, also known as beta.
  ///   - scale: The scalar scale, also known as gamma.
  ///   - epsilon: A small value added to the denominator for numerical
  ///     stability.
  @inlinable @inline(__always)
  @differentiable(
    wrt: (self, .1, .2), adjoint: _adjointBatchNormalized
    where Scalar : Differentiable, Scalar == Scalar.CotangentVector
  )
  func batchNormalized(
    alongAxis axis: Int32,
    offset: Scalar = 0,
    scale: Scalar = 1,
    epsilon: Scalar = 0.001
  ) -> Tensor {
    let mean = self.mean(alongAxes: axis)
    let squaredDiff: Tensor = Raw.squaredDifference(self, mean)
    let variance = squaredDiff.mean(alongAxes: axis)
    let inv = rsqrt(variance + epsilon) * scale
    return self * inv + offset - mean * inv
  }
}

//===----------------------------------------------------------------------===//
// Convolution and pooling
//===----------------------------------------------------------------------===//

/// A padding scheme. Used by padding, convolution, and pooling ops.
@_frozen
public enum Padding {
  /// The "valid" padding scheme.
  case valid
  /// The "same" padding scheme.
  case same
}

internal extension Padding {
  @inlinable
  var raw: Raw.Padding {
    @inline(__always)
    get {
      switch self {
      case .same: return .same
      case .valid: return .valid
      }
    }
  }
}

public extension Tensor where Scalar : FloatingPoint {
  /// Computes a 2-D convolution using `self` as input, with the specified
  /// filter, strides, and padding.
  ///
  /// - Parameters:
  ///   - filter: The convolution filter.
  ///   - strides: The strides of the sliding filter for each dimension of the
  ///     input.
  ///   - padding: The padding for the operation.
  /// - Precondition: `self` must have rank 4.
  /// - Precondition: `filter` must have rank 4.
  @inlinable @inline(__always)
  @differentiable(
    wrt: (self, .0),
    adjoint: _adjointConvolved2D(seed:originalValue:filter:strides:padding:)
    where Scalar : Differentiable
  )
  func convolved2D(
    withFilter filter: Tensor,
    strides: (Int32, Int32, Int32, Int32),
    padding: Padding
  ) -> Tensor {
    return Raw.conv2D(
      self,
      filter: filter,
      strides: [strides.0, strides.1, strides.2, strides.3],
      padding: padding.raw)
  }

  /// Computes a 2-D max pooling, with the specified kernel sizes, strides, and
  /// padding.
  ///
  /// - Parameters:
  ///   - kernelSize: The dimensions of the pooling kernel.
  ///   - strides: The strides of the sliding filter for each dimension of the
  ///     input.
  ///   - padding: The padding for the operation.
  @inlinable @inline(__always)
  @differentiable(
    wrt: (self),
    adjoint: _adjointMaxPooled(seed:originalValue:kernelSize:strides:padding:)
    where Scalar : Differentiable
  )
  func maxPooled(
    kernelSize: (Int32, Int32, Int32, Int32),
    strides: (Int32, Int32, Int32, Int32),
    padding: Padding
  ) -> Tensor {
    return Raw.maxPoolV2(
      self,
      ksize: Tensor<Int32>(kernelSize),
      strides: Tensor<Int32>(strides),
      padding: padding.raw)
  }

  /// Computes a 2-D average pooling, with the specified kernel sizes, strides,
  /// and padding.
  ///
  /// - Parameters:
  ///   - kernelSize: The dimensions of the pooling kernel.
  ///   - strides: The strides of the sliding filter for each dimension of the
  ///     input.
  ///   - padding: The padding for the operation.
  @inlinable @inline(__always)
  @differentiable(
    wrt: (self),
    adjoint: _adjointAveragePooled(seed:originalValue:kernelSize:strides:padding:)
    where Scalar : Differentiable
  )
  func averagePooled(
    kernelSize: (Int32, Int32, Int32, Int32),
    strides: (Int32, Int32, Int32, Int32),
    padding: Padding
  ) -> Tensor {
    return Raw.avgPool(
      value: self,
      ksize: [kernelSize.0, kernelSize.1, kernelSize.2, kernelSize.3],
      strides: [strides.0, strides.1, strides.2, strides.3],
      padding: padding.raw)
  }
}