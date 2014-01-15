## Various possible plot interfaces


## Plot interfaces for functions

## plot(x, [y], args..., kwargs...) lineplot
## plot(x::Tuple{Vector}, args...; symboltype::String="o", kwargs...) scatter plot
## plot(f, a::Real, b::Real, args...; kwargs...)  function plot using 
## plot(fs::Tuple{Function}, a, b; kwargs) parametric plot
## plot(fs::Vector{Function}, a::Real, b::Real, args...; kwargs...) function plot, overlay
## plot(fs::Array{Function, 2}, a::Real, b::Real, args...; kwargs...) table of plots





typealias ScatterPlotPoints{T<:Real, S<:Real} (Vector{T}, Vector{S})

## plot a scatterplot (verbose alternative to plot(x, y, "o") 
## use named argument symbol to pass in symbol -- not args)
function plot(p::FramedPlot, x::ScatterPlotPoints, args...; symbol="o", kwargs...)
    plot(p, x[1], x[2], symbol, args...;  kwargs...)
end

## function plot
function plot(p::FramedPlot, f::Function, a::Real, b::Real, args...;  kwargs...)
    xs, ys = fplot_points(f, a, b, min_points=100)
    plot(p, xs, ys, args...; kwargs...)
end

## multiple plots on one
## kwargs vectorized, not recycled
## e.g.:  plot([sin, cos], 0, 2pi, color=["blue", "red"]) 
function plot(p::FramedPlot, fs::Vector{Function}, a::Real, b::Real, args...; kwargs...)
   
    f = fs[1]

    xs, ys = fplot_points(f, a, b, min_points=100)
    kws = [(k, v[1]) for (k,v) in kwargs]
    plot(p, xs, ys, args...; kws...)

    for i in 2:length(fs)
        xs, ys = fplot_points(fs[i], a, b, tol=1e-3)
        kws = [(k, v[i]) for (k,v) in kwargs]
        plot(p, xs, ys, args...;  kws...)
    end

    p
    
end

errs_to_nan(f) = (x) -> try f(x) catch e NaN end

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
