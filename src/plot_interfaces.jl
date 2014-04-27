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

