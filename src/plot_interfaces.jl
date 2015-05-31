## Various possible plot interfaces


## Plot interfaces for functions

## plot(x, [y], args..., kwargs...) lineplot
## plot(x::Tuple{Vector}, args...; symboltype::String="o", kwargs...) scatter plot
## plot(fs::Tuple{Function}, a, b; kwargs) parametric plot
## plot(fs::Array{Function, 2}, a::Real, b::Real, args...; kwargs...) table of plots


typealias ScatterPlotPoints{T<:Real, S<:Real} @compat(Tuple{Vector{T}, Vector{S}})

## plot a scatterplot (verbose alternative to plot(x, y, "o")
## use named argument symbol to pass in symbol -- not args)
function plot(p::FramedPlot, x::ScatterPlotPoints, args...; symbol="o", kwargs...)
    Base.warn_once("deprecated -- call scatter instead")
    plot(p, x[1], x[2], symbol, args...;  kwargs...)
end

errs_to_nan(f) = (x) -> try f(x) catch e NaN end

## parametric plot
typealias ParametricFunctionPair @compat(Tuple{Function, Function})
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

