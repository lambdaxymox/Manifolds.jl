using StatsBase: AbstractWeights, Weights, ProbabilityWeights, values, varcorrection
@doc doc"""
    mean(M, x, weights=Weights(ones(n)); x0=x[1], stop_iter=100, kwargs... )

computes the Riemannian center of mass also known as Karcher mean of the vector
`x` of `n` points on the [`Manifold`](@ref) `M`. This function
uses the gradient descent scheme. Optionally one can provide
weights $w_i$ for the weighted Riemannian center of mass.
The general formula to compute the minimizer reads
````math
\argmin_{y\in\mathcal M} \frac{1}{2}\sum_{i=1}^n w_i\mathrm{d}_{\mathcal M}^2(y,x_i),
````
where $\mathrm{d}_{\mathcal M}$ denotes the Riemannian [`distance`](@ref).

Note that any provided weights are normalized to
$\displaystyle\sum_{i=1}^n w_i=1$.

Optionally you can provide `x0`, the starting point (by default set to the first
data point). `stop_iter` denotes the maximal number of iterations to perform and
the `kwargs...` are passed to [`isapprox`](@ref) to stop, when the minimal change
between two iterates is small. For more stopping criteria
check the [`Manopt.jl`](https://manoptjl.org) package and use a solver therefrom.

The algorithm is further described in
> Afsari, B; Tron, R.; Vidal, R.: On the Convergence of Gradient
> Descent for Finding the Riemannian Center of Mass,
> SIAM Journal on Control and Optimization (2013), 51(3), pp. 2230–2260,
> doi: [10.1137/12086282X](https://doi.org/10.1137/12086282X),
> arxiv: [1201.0925](https://arxiv.org/abs/1201.0925)
"""
function mean(M::Manifold, x::AbstractVector, w::AbstractWeights = (n = length(x); Weights(ones(n), n)); x0 = x[1], kwargs...)
    y = similar_result(M, mean, x0)
    copyto!(y,x0)
    return mean!(M, y, x, w; kwargs...)
end
@doc doc"""
    mean!(M,y,x,w)

computes the [`mean`](@ref) in-place in `y` where the initial value of `y` is
the starting point of the algorithm.
"""
function mean!(M::Manifold, y, x::AbstractVector, w::AbstractWeights = (n = length(x); Weights(ones(n), n));
            stop_iter=100,
            kwargs...
        ) where {T}
    yold = similar_result(M, mean, y)
    copyto!(yold,y)
    v0 = zero_tangent_vector(M, y)
    v = map(_ -> copy(v0), x)
    wreg = convert(Vector, w) ./ (2 * w.sum)
    for i=1:stop_iter
        copyto!(yold,y)
        log!.(Ref(M), v, Ref(yold), x)
        vreg = sum(wreg .* v)
        exp!(M, y, yold, vreg)
        isapprox(M,y,yold; kwargs...) && break
    end
    return y
end

@doc doc"""
    median(M, x, weights=Weights(ones(n)); stop_iter=10000)

computes the Riemannian median of the vector `x`  of `n` points on the
[`Manifold`](@ref) `M`. This function is nonsmooth (i.e nondifferentiable) and
uses a cyclic proximal point scheme. Optionally one can provide
weights $w_i$ for the weighted Riemannian median. The general formula to compute
the minimizer reads
````math
\argmin_{y\in\mathcal M}\sum_{i=1}^n w_i\mathrm{d}_{\mathcal M}(y,x_i),
````
where $\mathrm{d}_{\mathcal M}$ denotes the Riemannian [`distance`](@ref).

Optionally you can provide `x0`, the starting point (by default set to the first
data point). `stop_iter` denotes the maximal number of iterations to perform and
the `kwargs...` are passed to [`isapprox`](@ref) to stop, when the minimal change
between two iterates is small. For more stopping criteria
check the [`Manopt.jl`](https://manoptjl.org) package and use a solver therefrom.

The algorithm is further described in Algorithm 4.3 and 4.4 in
> Bačák, M: Computing Medians and Means in Hadamard Spaces.
> SIAM Journal on Optimization (2014), 24(3), pp. 1542–1566,
> doi: [10.1137/140953393](https://doi.org/10.1137/140953393),
> arxiv: [1210.2145](https://arxiv.org/abs/1210.2145)
"""
function median(M::Manifold, x::AbstractVector, w::AbstractWeights = (n = length(x); Weights(ones(n), n)); x0=x[1], kwargs...)
    y = similar_result(M, median, x[1])
    copyto!(y,x0)
    return median!(M, y, x, w; kwargs...)
end
@doc doc"""
    median!(M,y,x,w)

computes the [`median`](@ref) in-place in `y` where the initial value of `y` is
the starting point of the algorithm.
"""
function median!(M::Manifold, y, x::AbstractVector,
    w::AbstractWeights = (n = length(x); Weights(ones(n), n));
    stop_iter=1000000,
    kwargs...
) where {T}
    n = length(x)
    yold = similar_result(M,median,y)
    ytmp = copy(yold)
    (length(w) != n) && throw(DimensionMismatch("The number of weights ($(length(w))) does not match the number of points for the median ($(n))."))
    v = zero_tangent_vector(M,y)
    wv = convert(Vector, w) ./ w.sum
    for i=1:stop_iter
        λ =  .5 / i
        copyto!(yold,y)
        for j in 1:n
            @inbounds t = min( λ * wv[j] / distance(M,y,x[j]), 1. )
            @inbounds log!(M, v, y, x[j])
            exp!(M, ytmp, y, v, t)
            copyto!(y,ytmp)
        end
        isapprox(M, y, yold; kwargs...) && break
    end
    return y
end
@doc doc"""
    var(M, x, w::AbstractWeights, m=nothing; corrected=false, kwargs...)

compute the (weighted) variance of a `Vector` `x` of `n` data points on the
[`Manifold`](@ref) `M`, i.e.

````math
\frac{1}{c} \sum_{i=1}^n w_i d_{\mathcal M}^2 (x_i,m),
````
where `c` is a correction term, see
[Statistics.var](https://juliastats.org/StatsBase.jl/stable/scalarstats/#Statistics.var).
The (weighted) mean of `x` can be specified as `m`, and the corrected variance
can be activated by setting `corrected=true`. All further `kwargs...` are passed
to the computation of the mean (if that is not provided).
"""
function var(
    M::Manifold,
    x::AbstractVector,
    w::AbstractWeights,
    m = nothing;
    corrected::Bool = false,
    kwargs...
)
    if (m === nothing)
        m = mean(M, x, w; kwargs...)
    end
    wv = convert(Vector, w)
    sqdist = wv .* distance.(Ref(M), Ref(m), x) .^ 2
    s = sum(sqdist)
    c = varcorrection(w, corrected)
    return c * s
end
@doc doc"""
    var(M, x, m=nothing; corrected=true, kwargs...)

compute the variance of a `Vector` `x` of `n` data points on the
[`Manifold`](@ref) `M`, i.e.

````math
\frac{1}{c} \sum_{i=1}^n d_{\mathcal M}^2 (x_i,m),
````
where `c` is a correction term, see
[Statistics.var](https://juliastats.org/StatsBase.jl/stable/scalarstats/#Statistics.var).
and `m` is the provideed mean of `x`. The uncorrected variance
can be activated by setting `corrected=false`.
"""
function var(
    M::Manifold,
    x::AbstractVector,
    m = nothing;
    corrected::Bool = true,
    kwargs...
)
    if (m === nothing)
        m = mean(M, x; kwargs...)
    end
    n = length(x)
    w = ProbabilityWeights(ones(n), n)
    return var(M, x, w, m; corrected = corrected, kwargs...)
end
@doc doc"""
    std(M, x, w::AbstractWeights, m=nothing; corrected=false, kwargs...)

compute the (weighted) standard deviation of a `Vector` `x` of `n` data points on the
[`Manifold`](@ref) `M`, i.e.

````math
\sqrt{\frac{1}{c} \sum_{i=1}^n w_i d_{\mathcal M}^2 (x_i,m)},
````
where `c` is a correction term, see
[Statistics.var](https://juliastats.org/StatsBase.jl/stable/scalarstats/#Statistics.var).
The (weighted) mean of `x` can be specified as `m`, and the corrected variance
can be activated by setting `corrected=true`. All further `kwargs...` are passed
to the computation of the mean (if that is not provided).
"""
function std(
    M::Manifold,
    x::AbstractVector,
    w::AbstractWeights,
    m = nothing;
    corrected::Bool = false,
    kwargs...
)
    return sqrt(var(M, x, w, m; corrected = corrected, kwargs...))
end
@doc doc"""
    std(M, x, m=nothing; corrected=true, kwargs...)

compute the variance of a `Vector` `x` of `n` data points on the
[`Manifold`](@ref) `M`, i.e.

````math
\sqrt{\frac{1}{c} \sum_{i=1}^n d_{\mathcal M}^2 (x_i,m)},
````
where `c` is a correction term, see
[Statistics.var](https://juliastats.org/StatsBase.jl/stable/scalarstats/#Statistics.var).
and `m` is the provideed mean of `x`.
"""
function std(
    M::Manifold,
    x::AbstractVector,
    m = nothing;
    corrected::Bool = true,
    kwargs...
)
    return sqrt(var(M, x, m; corrected = corrected, kwargs...))
end

@doc doc"""
    mean_and_var(M, x, w; corrected = false, kwargs...) -> (mean, var)
    mean_and_var(M, x; corrected = true, kwargs...) -> (mean, var)

compute the [`mean`](@ref) `m` and the [`var`](@ref)iance `v` simultaneously.
"""
function mean_and_var(
    M::Manifold,
    x::AbstractVector,
    w::AbstractWeights;
    corrected = false,
    kwargs...
)
    m = mean(M, x, w; kwargs...)
    v = var(M, x, w, m; corrected = corrected, kwargs...)
    return m, v
end

function mean_and_var(
    M::Manifold,
    x::AbstractVector;
    corrected = true,
    kwargs...
)
    n = length(x)
    w = ProbabilityWeights(ones(n), n)
    m = mean(M, x, w; kwargs...)
    v = var(M, x, w, m; corrected = corrected, kwargs...)
    return m, v
end

@doc doc"""
    mean_and_std(M, x, w; corrected = false, kwargs...) -> (mean, std)
    mean_and_std(M, x; corrected = true, kwargs...) -> (mean, std)

compute the [`mean`](@ref) `m` and the standard deviation [`std`](@ref) `s`
simultaneously.
"""
function mean_and_std(
    M::Manifold,
    x::AbstractVector,
    w::AbstractWeights;
    corrected = false,
    kwargs...
)
    m = mean(M, x, w; kwargs...)
    s = std(M, x, w, m; corrected = corrected, kwargs...)
    return m, s
end

function mean_and_std(
    M::Manifold,
    x::AbstractVector;
    corrected = true,
    kwargs...
)
    m, v = mean_and_var(M, x; corrected = corrected, kwargs...)
    return m, √v
end