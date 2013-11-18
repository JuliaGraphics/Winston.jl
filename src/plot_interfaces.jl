## Various possible plot interfaces


## Plot interfaces for functions

## plot(x, [y], args..., kwargs...) lineplot
## plot(x::Tuple{Vector}, args...; symboltype::String="o", kwargs...) scatter plot
## plot(f, a::Real, b::Real, args...; kwargs...)  function plot using adaptive point, a, b length two atleast
## plot(fs::Tuple{Function}, a, b; kwargs) parametric plot
## plot(fs::Vector{Function}, a::Real, b::Real, args...; kwargs...) function plot, overlay
## plot(fs::Array{Function, 2}, a::Real, b::Real, args...; kwargs...) table of plots


errs_to_nan(f) = (x) -> try f(x) catch e NaN end


typealias ScatterPlotPoints{T<:Real, S<:Real} (Vector{T}, Vector{S})

function plot(p::FramedPlot, x::ScatterPlotPoints, args...; symbolkind="circle",kwargs...)
    #XXX: check if args have symbolkind options
    plot(p, x[1], x[2], args...; symbolkind=symbolkind, kwargs...)
end

function plot(p::FramedPlot, f::Function, a::Real, b::Real, args...;  kwargs...)
    xs = adaptive_points(f, a, b)
    ys = map(errs_to_nan(f), xs)
    plot(p, xs, ys, args...; kwargs...)
end

## multiple plots on one
## kwargs vectorized, not recycled
## e.g.:  plot([sin, cos], 0, 2pi, color=["blue", "red"]) 
function plot(p::FramedPlot, fs::Vector{Function}, a::Real, b::Real, args...; kwargs...)
   
    f = fs[1]

    xs = adaptive_points(f, a, b)
    ys = map(errs_to_nan(f), xs)
    kws = [(k, v[1]) for (k,v) in kwargs]
    plot(p, xs, ys, args...; kws...)

    for i in 2:length(fs)
        xs = adaptive_points(fs[i], a, b)
        ys = map(errs_to_nan(fs[i]), xs)
        kws = [(k, v[i]) for (k,v) in kwargs]
        plot(p, xs, ys, args...;  kws...)
    end

    p
    
end

## parametric plot
typealias ParametricFunctionPair (Function, Function)
function plot(p::FramedPlot, fs::ParametricFunctionPair, a::Real, b::Real, args...; npoints::Int=500, kwargs...)
    us = linspace(a, b, npoints)
    xs = map(errs_to_nan(fs[1]), us)
    ys = map(errs_to_nan(fs[2]), us)
    plot(p, xs, ys, args...; kwargs...)
end


## Array
## kwargs are vectorized (without recycling)
## e.g.:  plot([sin cos]', 0, 2pi, color=["blue" "red"]') 
function plot(fs::Array{Function, 2}, a::Real, b::Real, args...; kwargs...)
    m,n = size(fs)
    tbl = Table(m, n)
    for i in 1:m, j in 1:n
        f = fs[i,j]
        kws = [(k, v[i,j]) for (k, v) in kwargs]
        p = plot(f, a, b, args...; kws...)
        tbl[i,j] = p
    end

    tbl
end

## adaptive plotting
## algorithm from http://yacas.sourceforge.net/Algochapter4.html
## use of heaps follows roughly quadgk.jl


using Base.Collections
import Base.isless, Base.Order.Reverse


immutable Segment
    a::Number
    b::Number
    depth::Int
    E::Real
end

isless(i::Segment, j::Segment) = isless(i.E, j.E)

function evalrule(f, a, b; depth::Int=0)
    xs = linspace(a, b, 7)[2:6] # avoid edges?
    y = [try f(x) catch e NaN end for x in xs]

    if all(map(isnan,y))
        error("Function does not evaluate to a real number at initial set of points in the interval ($a, $b)")
    end

    wiggles(x,y,z) = any(map(u->isinf(u) | isnan(u), [x,y,z])) || (y < min(x,z)) || (y > max(x,z)) ? 1 : 0
    wiggly = [wiggles(y[i:i+2]...) for i in 1:3]
    
    if depth < 0
        E = 0
    elseif sum(wiggly) > 2 
        E = 1
    else
        ## not too wiggly, but may not approximate well enough
        g = y - minimum(y)
        E = (1/3)*abs( (y[1] + 4*y[2] + y[3]) - (y[3] + 4*y[4] + y[5])) # no h = (b-a)/2
    end
    Segment(a, b, depth, E)
end
        

function adaptive_points(f::Function, a::Real, b::Real;
                             tol::Real=1e-3,
                             max_depth::Int=6)
            
    n = 100
    s = (a+b)/2 + (b-a)/2* cos((n:-1:0) * pi/n) # non even, to avoid antialiasing. Overkill?
    segs = Segment[]
    for i in 1:n
        heappush!(segs, evalrule(f, s[i], s[i+1], depth=max_depth), Reverse)
    end

    E = segs[1].E
    
    while E > tol
        s = heappop!(segs, Reverse)
        mid = (s.a + s.b) * 0.5
        s1 = evalrule(f, s.a, mid, depth=s.depth - 1)
        s2 = evalrule(f, mid, s.b, depth=s.depth - 1)
        heappush!(segs, s1, Reverse)
        heappush!(segs, s2, Reverse)
        E = segs[1].E
    end
    
    x = Float64[]
    [append!(x, [s.a, s.b]) for s in segs]
    x = sort!(x)
    x
end
    



## Contour plot -- but this is too slow to be usable
## algorithm from MATLAB
## cf. http://www.mathworks.com/help/matlab/creating_plots/contour-plots.html
type Contourc
    contours
end

function contourc(f::Function, x, y; cs::Union(Nothing, Number)=nothing)

    fxy = [f(x,y) for x in x, y in y] 

    ## we have edges 1,2,3,4
    ## with 1 on bottom, 2 on right, 3 top, 4 left. So
    ## exiting 1 goes to 3; 2->4, 3->1 and 4->2

    ## helper functions
    prop(c, z0, z1) = (c - z0)/(z1-z0)
    function interp_square(c, i,j)
        ## worry of i,j on boundary of 1:length(x), length(y)
        if (i < 1 || i >= length(x)) || (j < 1 || j >= length(y))
            return -1 * ones(4)
        else
            [prop(c, fxy[i,j], fxy[i+1,j]),
             prop(c, fxy[i+1,j], fxy[i+1, j+1]),
             prop(c, fxy[i,j+1], fxy[i+1, j+1]),
             prop(c, fxy[i,j], fxy[i, j+1])]
        end
    end
    insquare(x) =  any(0 .<= x .<= 1)
        
    function interp_point(edge, i, j, t)
        if edge == 1
            newx = x[i] + t*(x[i+1] - x[i])
            newy = y[j]
        elseif edge == 2
            newx = x[i+1]
            newy = y[j] + t*(y[j+1] - y[j])
        elseif edge == 3
            newx = x[i] + t*(x[i+1] - x[i])
            newy = y[j+1] 
        else
            newx = x[i]
            newy = y[j] + t*(y[j+1] - y[j])
        end
        (newx, newy)
    end

    function which_next(edge, i, j)
        if edge == 1
            (i, j-1)
        elseif edge == 2
            (i+1, j)
        elseif edge == 3
            (i, j+1)
        else
            (i-1, j)
        end
    end
    


    function next_square(c, i, j, enter_edge, cx, cy, m)
##        println("Chasing $i $j")
        
        
        sq = interp_square(c, i, j)
        w = 0 .<= sq .<= 1
        ## check if 2 or more (saddle point) XXX
        
        ## what is next edge?
        if enter_edge == 1
            next_edge = setdiff((1:4)[w], 3)
        elseif enter_edge == 2
            next_edge = setdiff((1:4)[w], 4)
        elseif enter_edge == 3
            next_edge = setdiff((1:4)[w], 1)
        else
            next_edge = setdiff((1:4)[w], 2)
        end
        
        if length(next_edge) == 0
            return (cx, cy)
        end
        
        next_edge = next_edge[1]
        
        ##
        newx, newy = interp_point(next_edge, i, j, sq[next_edge])
        push!(cx, newx); push!(cy, newy)

        if m[i,j] == 1
            ## already visited
            return (cx, cy)
        end
        m[i,j] = 1
        next_square(c, which_next(next_edge, i,j)..., next_edge, cx, cy, m)
    end
    
    function chase_square(c, i, j, m)
##        println("chase $i $j")
        
        sq = interp_square(c, i, j)
        w = 0 .<= sq .<= 1

        ## chase both edges, then put together
        edges = [1:4][w]
        ## should be 2, might be more (saddle point)

        m[i,j] = 1                  # visited
        
        out = map(edges) do edge
            cx = Float64[]; cy = Float64[]
            t = sq[edge]
            newx, newy = interp_point(edge, i,j,t)
            push!(cx, newx); push!(cy, newy)
            next_square(c, which_next(edge, i,j)..., edge, cx, cy, m)
        end
        ## out is array of tuples
        if !isa(out[1], Nothing)
            ([reverse(out[1][1]), out[2][1]], [reverse(out[1][2]), out[2][2]])
        else
            nothing
        end

    end
    
    
    

## for each level to plot
    if isa(cs, Nothing)
        cs = linspace(min(fxy), max(fxy), 7+2)[2:8]
    else
        cs = [cs]
    end
    contours = {}

    for c in cs
        m = zeros(Int, size(fxy)...)
        c_contours = {}

        for i in 2:length(x)-1, j in 2:length(y)-1
            if m[i,j] == 1
                continue
            end
            sq = interp_square(c, i, j)
            if insquare(sq)
                path = chase_square(c, i,j, m)
##                println("Chased path:", path)
                if !isa(path, Nothing)
                    push!(c_contours, path)
                end
            else
                m[i,j] = 1              # visited
            end
        end
        push!(contours, (c, c_contours))
    end
    Contourc(contours)
end

## contour plot
function plot(f::Contourc; kwargs...)
    p = FramedPlot()
    ## out is array of tuples (c, c_countrous)
    for clevels in f.contours
        for contours in clevels[2]
            add(p, Curve(contours[1], contours[2]))
        end
    end
    for (k, v) in kwargs
        setattr(p, k, v)
    end

    p
end

              


# ## Some tests
# using Winston
# ## basic
# plot(sin, 0, 2pi) |> Winston.tk
# plot(x -> sin(1/x), 0, 1) |> Winston.tk

# ## attributes
# plot(sin, 0, 2pi, title="Title") |> Winston.tk

# ## parametric
# plot((x -> sin(2x), x -> cos(3x)), 0, 2pi) |> Winston.tk

# ## vector
# plot([sin, cos], 0, 2pi) |> Winston.tk

# ## table with arguments
# plot([sin cos; x->-sin(x) x->-cos(x)], 0, 2pi, title=["f" "f'(x)"; "f''(x)" "f'''(x)"]) |> Winston.tk



# ## contour plot
# f(x,y) = sin(x)*sin(y)
# x = linspace(-pi, pi, 50)
# y = linspace(-pi, pi, 50)
# c = Winston.contourc(f, x, y)
# plot(c) |> Winston.tk
