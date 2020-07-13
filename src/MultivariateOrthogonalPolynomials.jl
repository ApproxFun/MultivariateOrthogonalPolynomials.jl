module MultivariateOrthogonalPolynomials
using OrthogonalPolynomialsQuasi, FastTransforms, BlockBandedMatrices, BlockArrays, DomainSets, 
      QuasiArrays, StaticArrays, ContinuumArrays, InfiniteArrays, InfiniteLinearAlgebra, 
      LazyArrays, SpecialFunctions, LinearAlgebra

import Base: axes, in, ==, *, ^, copy
import DomainSets: boundary

import QuasiArrays: LazyQuasiMatrix
import ContinuumArrays: @simplify, Weight

import BlockBandedMatrices: _BandedBlockBandedMatrix

export Triangle, JacobiTriangle, TriangleWeight, WeightedTriangle, PartialDerivative, Laplacian

#########
# PartialDerivative{k}
# takes a partial derivative in the k-th index.
#########


struct PartialDerivative{k,T,D} <: LazyQuasiMatrix{T}
    axis::Inclusion{T,D}
end

PartialDerivative{k,T}(axis::Inclusion{<:Any,D}) where {k,T,D} = PartialDerivative{k,T,D}(axis)
PartialDerivative{k,T}(domain) where {k,T} = PartialDerivative{k,T}(Inclusion(domain))
PartialDerivative{k}(axis) where k = PartialDerivative{k,eltype(axis)}(axis)

axes(D::PartialDerivative) = (D.axis, D.axis)
==(a::PartialDerivative{k}, b::PartialDerivative{k}) where k = a.axis == b.axis
copy(D::PartialDerivative{k}) where k = PartialDerivative{k}(copy(D.axis))

struct Laplacian{T,D} <: LazyQuasiMatrix{T}
    axis::Inclusion{T,D}
end

Laplacian{T}(axis::Inclusion{<:Any,D}) where {T,D} = Laplacian{T,D}(axis)
Laplacian{T}(domain) where T = Laplacian{T}(Inclusion(domain))
Laplacian(axis) = Laplacian{eltype(axis)}(axis)

axes(D::Laplacian) = (D.axis, D.axis)
==(a::Laplacian, b::Laplacian) = a.axis == b.axis
copy(D::Laplacian) = Laplacian(copy(D.axis), D.k)

^(D::PartialDerivative, k::Integer) = ApplyQuasiArray(^, D, k)
^(D::Laplacian, k::Integer) = ApplyQuasiArray(^, D, k)

include("Triangle/Triangle.jl")


end # module
