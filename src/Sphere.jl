@doc doc"""
    Sphere{N} <: Manifold

The unit sphere manifold $\mathbb S^n$ represented by $n+1$-Tuples, i.e. in by
vectors in $\mathbb R^{n+1}$ of unit length

# Constructor

    Sphere(n)

generates the $\mathbb S^{n}\subset \mathbb R^{n+1}$
"""
struct Sphere{N} <: Manifold end
Sphere(n::Int) = Sphere{n}()

@doc doc"""
    manifold_dimension(S::Sphere)

returns the dimension of the manifold $\mathbb S^n$, i.e. $n$.
"""
manifold_dimension(S::Sphere{N}) where {N} = N

@doc doc"""
    dot(S,x,w,v)

compute the inner product of the two tangent vectors `w,v` from the tangent
plane at `x` on the sphere `S=`$\mathbb S^n$ using the restriction of the metric from the
embedding, i.e. $ (v,w)_x = v^\mathrm{T}w $.
"""
dot(S::Sphere, x, w, v) = dot(w, v)

proj!(S::Sphere, x) = (x ./= norm(x))

project_tangent!(S::Sphere, w, x, v) = (w .= v .- dot(x, v).*x)
distance(S::Sphere, x, y) = acos(dot(x, y))

function exp!(S::Sphere, y, x, v)
    nv = norm(S, x, v)
    if nv ≈ 0.0
        y .= x
    else
        y .= cos(nv).*x .+ (sin(nv)/nv).*v
    end
    return y
end

function log!(S::Sphere, v, x, y)
    dot_xy = dot(x, y)
    θ = acos(dot_xy)
    if θ ≈ 0.0
        zero_tangent_vector!(S, v, x)
    else
        v .= (θ/sin(θ)) .* (y .- dot_xy.*x)
    end
    return v
end

zero_tangent_vector(S::Sphere, x) = zero(x)
zero_tangent_vector!(S::Sphere, v, x) = (v .= zero(x))

"""
	uniform_sphere_distribution(S::Sphere, x)

Uniform distribution on given sphere. Generated points will be of similar
type to `x`.
"""
function uniform_sphere_distribution(S::Sphere, x)
	d = Distributions.MvNormal(zero(x), 1.0)
	return ProjectedPointDistribution(S, d, proj!, x)
end

"""
	gaussian_sphere_tvector_distribution(S::Sphere, x, σ)

Normal distribution in ambient space with standard deviation `σ`
projected to tangent space at `x`.
"""
function gaussian_sphere_tvector_distribution(S::Sphere, x, σ)
	d = Distributions.MvNormal(zero(x), σ)
	return ProjectedTVectorDistribution(S, x, d, project_tangent!, x)
end
