"""
Position nodes uniformly at random in the unit square.
For every node, a position is generated by choosing each of dim
coordinates uniformly at random on the interval [0.0, 1.0).

**Parameters**

*G*
graph or list of nodes,
A position will be assigned to every node in G

**Return**

*locs_x, locs_y*
Locations of the nodes. Can be any units you want,
but will be normalized and centered anyway

**Examples**

```
julia> g = simple_house_graph()

julia> loc_x, loc_y = random_layout(g)
```

"""
function random_layout(G)
    rand(_nv(G)), rand(_nv(G))
end

"""
This function wrap from [NetworkX](https://github.com/networkx/networkx)

Position nodes on a circle.

**Parameters**

*G*
a graph

**Returns**

*locs_x, locs_y*
Locations of the nodes. Can be any units you want,
but will be normalized and centered anyway

**Examples**

```
julia> g = simple_house_graph()
julia> locs_x, locs_y = circular_layout(g)
```
"""
function circular_layout(G)
    if _nv(G) == 1
        return [0.0], [0.0]
    else
        # Discard the extra angle since it matches 0 radians.
        θ = linspace(0, 2pi, _nv(G) + 1)[1:end-1]
        return cos(θ), sin(θ)
    end
end

"""
This function is copy from [IainNZ](https://github.com/IainNZ)'s [GraphLayout.jl](https://github.com/IainNZ/GraphLayout.jl)

Use the spring/repulsion model of Fruchterman and Reingold (1991):

+ Attractive force:  f_a(d) =  d^2 / k
+ Repulsive force:  f_r(d) = -k^2 / d

where d is distance between two vertices and the optimal distance
between vertices k is defined as C * sqrt( area / num_vertices )
where C is a parameter we can adjust

**Parameters**

*G*
a graph

*C*
Constant to fiddle with density of resulting layout

*MAXITER*
Number of iterations we apply the forces

*INITTEMP*
Initial "temperature", controls movement per iteration

**Examples**
```
julia> g = graphfamous("karate")
julia> locs_x, locs_y = spring_layout(g)
```
"""
function spring_layout(G, locs_x=2*rand(_nv(G)).-1.0, locs_y=2*rand(_nv(G)).-1.0; C=2.0, MAXITER=100, INITTEMP=2.0)

    #size(adj_matrix, 1) != size(adj_matrix, 2) && error("Adj. matrix must be square.")
    const N = _nv(G)
    adj_matrix = _adjacency_matrix(G)

    # The optimal distance bewteen vertices
    const K = C * sqrt(4.0 / N)

    # Store forces and apply at end of iteration all at once
    force_x = zeros(N)
    force_y = zeros(N)

    # Iterate MAXITER times
    @inbounds for iter = 1:MAXITER
        # Calculate forces
        for i = 1:N
            force_vec_x = 0.0
            force_vec_y = 0.0
            for j = 1:N
                i == j && continue
                d_x = locs_x[j] - locs_x[i]
                d_y = locs_y[j] - locs_y[i]
                d   = sqrt(d_x^2 + d_y^2)
                if adj_matrix[i,j] != zero(eltype(adj_matrix)) || adj_matrix[j,i] != zero(eltype(adj_matrix))
                    # F = d^2 / K - K^2 / d
                    F_d = d / K - K^2 / d^2
                else
                    # Just repulsive
                    # F = -K^2 / d^
                    F_d = -K^2 / d^2
                end
                # d  /          sin θ = d_y/d = fy/F
                # F /| dy fy    -> fy = F*d_y/d
                #  / |          cos θ = d_x/d = fx/F
                # /---          -> fx = F*d_x/d
                # dx fx
                force_vec_x += F_d*d_x
                force_vec_y += F_d*d_y
            end
            force_x[i] = force_vec_x
            force_y[i] = force_vec_y
        end
        # Cool down
        TEMP = INITTEMP / iter
        # Now apply them, but limit to temperature
        for i = 1:N
            force_mag  = sqrt(force_x[i]^2 + force_y[i]^2)
            scale      = min(force_mag, TEMP)/force_mag
            locs_x[i] += force_x[i] * scale
            #locs_x[i]  = max(-1.0, min(locs_x[i], +1.0))
            locs_y[i] += force_y[i] * scale
            #locs_y[i]  = max(-1.0, min(locs_y[i], +1.0))
        end
    end

    # Scale to unit square
    min_x, max_x = minimum(locs_x), maximum(locs_x)
    min_y, max_y = minimum(locs_y), maximum(locs_y)
    function scaler(z, a, b)
        2.0*((z - a)/(b - a)) - 1.0
    end
    map!(z -> scaler(z, min_x, max_x), locs_x)
    map!(z -> scaler(z, min_y, max_y), locs_y)

    return locs_x,locs_y
end

"""
This function is copy from [IainNZ](https://github.com/IainNZ)'s [GraphLayout.jl](https://github.com/IainNZ/GraphLayout.jl)

Position nodes in concentric circles.

**Parameters**

*G*
a graph

*nlist*
Vector of Vector, Vector of node Vector for each shell.

**Examples**
```
julia> g = graphfamous("karate")
julia> nlist = Array(Vector{Int}, 2)
julia> nlist[1] = [1:5]
julia> nlist[2] = [6:num_vertiecs(g)]
julia> locs_x, locs_y = shell_layout(g, nlist)
```
"""
function shell_layout(G, nlist::Union{Void, Vector{Vector{Int}}} = nothing)
    if _nv(G) == 1
        return [0.0], [0.0]
    end
    if nlist == nothing
        nlist = Array(Vector{Int}, 1)
        nlist[1] = collect(1:_nv(G))
    end
    radius = 0.0
    if length(nlist[1]) > 1
        radius = 1.0
    end
    locs_x = Float64[]
    locs_y = Float64[]
    for nodes in nlist
        # Discard the extra angle since it matches 0 radians.
        θ = linspace(0, 2pi, length(nodes) + 1)[1:end-1]
        append!(locs_x, radius*cos(θ))
        append!(locs_y, radius*sin(θ))
        radius += 1.0
    end
    locs_x, locs_y
end

"""
This function wrap from [NetworkX](https://github.com/networkx/networkx)

Position nodes using the eigenvectors of the graph Laplacian.

**Parameters**

*G*
a graph

*weight*
array or nothing, optional (default=nothing)
The edge attribute that holds the numerical value used for
the edge weight.  If None, then all edge weights are 1.

**Examples**
```
julia> g = graphfamous("karate")
julia> weight = rand(num_edges(g))
julia> locs_x, locs_y = spectral_layout(g, weight)
```
"""
function spectral_layout(G)
    if _nv(G) == 1
        return [0.0], [0.0]
    end

    if _nv(G) > 500
        A = sparse(Int[_src(e) for e in _edges(G)],
                   Int[_dst(e) for e in _edges(G)],
                   weight, _nv(G), _nv(G))
        if _is_directed(G)
            A = A + A'
        end
        return _spectral(A)
    else
        L = _laplacian_matrix(G)
        return _spectral(full(L))
    end
end

function _spectral(L::Matrix)
    eigenvalues, eigenvectors = eig(L)
    index = sortperm(eigenvalues)[2:3]
    eigenvectors[:, index[1]], eigenvectors[:, index[2]]
end

function _spectral(A::SparseMatrixCSC)
    data = collect(sum(A, 1))
    D = sparse([1:length(data)], [1:length(data)], data)
    L = D - A
    ncv = max(7, int(sqrt(length(data))))
    eigenvalues, eigenvectors = eigs(L, nev=3, ncv=ncv)
    index = sortperm(real(eigenvalues))[2:3]
    real(eigenvectors[:, index[1]]), real(eigenvectors[:, index[2]])
end
