
_hold = false
hold() = (global _hold = !_hold)
hold(h::Bool) = (global _hold = h)

function ghf()
    if !_hold
        global _pwinston = FramedPlot()
    end
    _pwinston
end
ghf(p) = (global _pwinston = p)

savefig(fname::AbstractString, args...; kvs...) = savefig(_pwinston, fname, args...; kvs...)
@deprecate file savefig

for f in (:xlabel,:ylabel,:title)
    @eval $f(s::AbstractString) = (setattr(_pwinston, $f=s); _pwinston)
end
for (f,k) in ((:xlim,:xrange),(:ylim,:yrange))
    @eval $f(a, b) = (setattr(_pwinston, $k=(a,b)); _pwinston)
    @eval $f(a) = (setattr(_pwinston, $k=(a[1],a[2])); _pwinston)
    @eval $f() = $k(limits(_pwinston))
end

const chartokens = @Dict(
    '-' => (:linekind, "solid"),
    ':' => (:linekind, "dotted"),
    ';' => (:linekind, "dotdashed"),
    '+' => (:symbolkind, "plus"),
    'o' => (:symbolkind, "circle"),
    '*' => (:symbolkind, "asterisk"),
    '.' => (:symbolkind, "dot"),
    'x' => (:symbolkind, "cross"),
    's' => (:symbolkind, "square"),
    'd' => (:symbolkind, "diamond"),
    '^' => (:symbolkind, "triangle"),
    'v' => (:symbolkind, "down-triangle"),
    '>' => (:symbolkind, "right-triangle"),
    '<' => (:symbolkind, "left-triangle"),
    'y' => (:color, colorant"yellow"),
    'm' => (:color, colorant"magenta"),
    'c' => (:color, colorant"cyan"),
    'r' => (:color, colorant"red"),
    'g' => (:color, colorant"green"),
    'b' => (:color, colorant"blue"),
    'w' => (:color, colorant"white"),
    'k' => (:color, colorant"black"),
)

function _parse_spec(spec::AbstractString)
    style = Dict()

    try
        style[:color] = parse(Colors.Colorant, spec)
        return style
    end

    for (k,v) in (("--","dashed"), ("-.","dotdashed"))
        splitspec = split(spec, k)
        if length(splitspec) > 1
            style[:linekind] = v
            spec = join(splitspec)
        end
    end

    for char in spec
        if haskey(chartokens, char)
            (k,v) = chartokens[char]
            style[k] = v
        else
            warn("unrecognized style '$char'")
        end
    end

    style
end

function default_color(i::Int)
    cs = [0x000000, 0xED2C30, 0x008C46, 0x1859A9,
          0xF37C21, 0x652B91, 0xA11C20, 0xB33794]
    cs[mod1(i,length(cs))]
end

function _process_keywords(kvs, p, components...)
    for (k,v) in kvs
        if k in [:angle,
                 :color,
                 :face,
                 :halign,
                 :linecolor,
                 :linekind,
                 :linewidth,
                 :size,
                 :symbolkind,
                 :symbolsize,
                 :valign]
            for c in components
                style(c, k, v)
            end
        else
            setattr(p, k, v)
        end
    end
end

typealias PlotArg Union{AbstractString,AbstractVector,AbstractMatrix,Function,Real}

isrowvec(x::AbstractArray) = ndims(x) == 2 && size(x,1) == 1 && size(x,2) > 1

isvector(x::AbstractVector) = true
isvector(x::AbstractMatrix) = size(x,1) == 1

function plot(p::FramedPlot, args::PlotArg...; kvs...)
    args = Any[args...]
    components = Any[]
    color_idx = 0

    default_style = Dict()
    attr = Any[]
    xrange = nothing
    for (k,v) in kvs
        if k in (:linestyle, :linetype)
            default_style[:linekind] = v
        elseif k in (:marker, :symboltype)
            default_style[:symbolkind] = v
        elseif k in (:markersize,)
            default_style[:symbolsize] = v
        elseif k in (:color, :linekind, :linewidth, :symbolkind, :symbolsize)
            default_style[k] = v
        else
            k == :xrange && (xrange = v)
            push!(attr, (k,v))
        end
    end

    # parse the args into tuples of the form (x, y, spec) or (func, lims, spec)
    parsed_args = Any[]

    i = 0
    need_xrange = false
    while length(args) > 0
        local x, y
        a = shift!(args); i += 1
        if isa(a, Function)
            x = a
            if length(args) > 1 && isa(args[1],Real) && isa(args[2],Real)
                y = (shift!(args),shift!(args)); i += 2
            else
                y = ()
                need_xrange = true
            end
        elseif isa(a, AbstractVecOrMat)
            elt = eltype(a)
            if elt <: Complex
                x = real(a)
                y = imag(a)
            elseif length(args) > 0 && isa(args[1], AbstractVecOrMat) &&
               elt <: Real && eltype(args[1]) <: Real
                x = a
                y = shift!(args); i += 1
            elseif elt <: Real
                y = a
                x = 1:(isrowvec(y) ? size(y,2) : size(y,1))
            else
                error("eltype of argument #$i is not Real or Complex")
            end
        else
            error("expected array or function for argument #$i; got $(typeof(a))")
        end
        spec = ""
        if length(args) > 0 && isa(args[1], AbstractString)
            spec = shift!(args); i += 1
        end
        push!(parsed_args, (x,y,spec))
    end

    need_xrange && xrange === nothing && error("need to specify xrange")

    for (a,b,spec) in parsed_args
        local x, y
        if isa(a, Function)
            xlim = b == () ? xrange : b
            x, y = fplot_points(a, xlim[1], xlim[2])
        else
            x, y = a, b
        end

        sopts = copy(default_style)
        spec != "" && merge!(sopts, _parse_spec(spec))

        no_color = !haskey(sopts, :color)
        add_curve = haskey(sopts, :linekind) || !haskey(sopts, :symbolkind)
        add_points = haskey(sopts, :symbolkind)

        isvector(x) && (x = vec(x))
        isvector(y) && (y = vec(y))

        local xys
        if isa(x, AbstractVector) && isa(y, AbstractVector)
            xys = [ (x,y) ]
        elseif isa(x, AbstractVector)
            xys = length(x) == size(y,1) ?
                  [ (x, sub(y,:,j)) for j = 1:size(y,2) ] :
                  [ (x, sub(y,i,:)) for i = 1:size(y,1) ]
        elseif isa(y, AbstractVector)
            xys = size(x,1) == length(y) ?
                  [ (sub(x,:,j), y) for j = 1:size(x,2) ] :
                  [ (sub(x,i,:), y) for i = 1:size(x,1) ]
        else
            @assert size(x) == size(y)
            xys = [ (sub(x,:,j), sub(y,:,j)) for j = 1:size(y,2) ]
        end

        for (x,y) in xys
            if no_color
                color_idx += 1
                sopts[:color] = default_color(color_idx)
            end
            if add_curve
                push!(components, Curve(x, y, sopts))
            end
            if add_points
                push!(components, Points(x, y, sopts))
            end
        end
    end

    for (k,v) in attr
        setattr(p, k, v)
    end

    for c in components
        add(p, c)
    end

    global _pwinston = p
    p
end
plot(args::PlotArg...; kvs...) = plot(ghf(), args...; kvs...)

# shortcut for overplotting
oplot(args::PlotArg...; kvs...) = plot(_pwinston, args...; kvs...)

# shortcuts for creating log plots
semilogx(args::PlotArg...; kvs...) = plot(args...; xlog=true, kvs...)
semilogy(args::PlotArg...; kvs...) = plot(args...; ylog=true, kvs...)
loglog(args::PlotArg...; kvs...) = plot(args...; xlog=true, ylog=true, kvs...)

typealias Interval @compat(Tuple{Real,Real})

function data2rgb{T<:Real}(data::AbstractArray{T}, limits::Interval, colormap::Array{UInt32,1})
    img = similar(data, UInt32)
    ncolors = length(colormap)
    limlower = limits[1]
    limscale = ncolors/(limits[2]-limits[1])
    for i = 1:length(data)
        datai = data[i]
        if isfinite(datai)
            idxr = limscale*(datai - limlower)
            idx = trunc(Int, idxr)
            idx += idxr > convert(T, idx)
            idx = clamp(idx, 1, ncolors)
            img[i] = colormap[idx]
        else
            img[i] = 0x00000000
        end
    end
    img
end

# from http://www.metastine.com/?p=7
function jetrgb(x)
    fourValue = 4x
    r = min(fourValue - 1.5, -fourValue + 4.5)
    g = min(fourValue - 0.5, -fourValue + 3.5)
    b = min(fourValue + 0.5, -fourValue + 2.5)
    RGB(clamp(r,0.,1.), clamp(g,0.,1.), clamp(b,0.,1.))
end

colormap() = (global _current_colormap; _current_colormap)
colormap(c::Array{UInt32,1}) = (global _current_colormap = c; nothing)
colormap{C<:Color}(cs::Array{C,1}) =
    colormap(UInt32[convert(RGB24,c) for c in cs])
function colormap(name::AbstractString, n::Int=256)
    if name == "jet"
        colormap([jetrgb(x) for x in linspace(0.,1.,n)])
    else
        colormap(Colors.colormap(name, n))
    end
end
colormap("jet")

function imagesc{T<:Real}(xrange::Interval, yrange::Interval, data::AbstractArray{T,2}, clims::Interval)
    p = ghf()
    if !_hold
        setattr(p, :xrange, xrange)
        setattr(p, :yrange, reverse(yrange))
    end
    img = data2rgb(data, clims, _current_colormap)
    xrange[1] > xrange[2] && (img = flipdim(img,2))
    yrange[1] < yrange[2] && (img = flipdim(img,1))
    add(p, Image(xrange, reverse(yrange), img))
    ghf(p)
end

imagesc(xrange, yrange, data) = imagesc(xrange, yrange, data, (minimum(data),maximum(data)+1))
imagesc(data) = ((h, w) = size(data); imagesc((0,w), (0,h), data))
imagesc{T}(data::AbstractArray{T,2}, clims::Interval) = ((h, w) = size(data); imagesc((0,w), (0,h), data, clims))

function spy(S::SparseMatrixCSC, nrS::Integer, ncS::Integer)
    m, n = size(S)
    colptr = S.colptr
    rowval = S.rowval
    nzval  = S.nzval

    if nrS > m; nrS = m; end
    if ncS > n; ncS = n; end

    target = zeros(nrS, ncS)
    x = nrS / m
    y = ncS / n

    for col = 1:n
        for k = colptr[col]:colptr[col+1]-1
            row = rowval[k]
            target[ceil(row * x), ceil(col * y)] += 1
        end
    end

    imagesc((1,m), (1,n), target)
end

scatter(x::AbstractVecOrMat, y::AbstractVecOrMat, spec::ASCIIString="o"; kvs...) = scatter(x, y, 1., spec; kvs...)
scatter{C<:Complex}(z::AbstractVecOrMat{C}, spec::ASCIIString="o"; kvs...) = scatter(real(z), imag(z), 1., spec; kvs...)
function scatter(x::AbstractVecOrMat, y::AbstractVecOrMat,
                 s::Real, spec::ASCIIString="o"; kvs...)
    sopts = _parse_spec(spec)
    p = ghf()
    c = Points(x, y, sopts, symbolsize=s)
    add(p, c)
    for (k,v) in kvs
        if k in [:linekind,:symbolkind,:color,:linecolor,:linewidth,:symbolsize]
            style(c, k, v)
        else
            setattr(p, k, v)
        end
    end
    ghf(p)
end
function scatter(x::AbstractVecOrMat, y::AbstractVecOrMat,
                 s::AbstractVecOrMat, spec::ASCIIString="o"; kvs...)
    c = convert(RGB24, color(get(_parse_spec(spec), :color, RGB(0,0,0))))
    scatter(x, y, s, fill(c,size(x)...), spec; kvs...)
end
function scatter(x::AbstractVecOrMat, y::AbstractVecOrMat,
                 s::Union{Real,AbstractVecOrMat}, c::AbstractVecOrMat,
                 spec::ASCIIString="o"; kvs...)
    if typeof(s) <: Real
        s = fill(s, size(x)...)
    end
    if eltype(c) <: Real
        c = data2rgb(c, extrema(c), _current_colormap)
    elseif !(eltype(c) <: Color)
        error("bad color array")
    end
    sopts = _parse_spec(spec)
    p = ghf()
    c = ColoredPoints(x, y, s, c, sopts)
    add(p, c)
    for (k,v) in kvs
        if k in [:linekind,:symbolkind,:color,:linecolor,:linewidth,:symbolsize]
            style(c, k, v)
        else
            setattr(p, k, v)
        end
    end
    ghf(p)
end

## stem ##

stem(y::AbstractVecOrMat, spec::ASCIIString="o"; kvs...) = stem(1:length(y), y, spec; kvs...)
function stem(x::AbstractVecOrMat, y::AbstractVecOrMat, spec::ASCIIString="o"; kvs...)
    p = ghf()
    sopts = _parse_spec(spec)
    s = Stems(x, y, sopts)
    haskey(sopts,:symbolkind) || (sopts[:symbolkind] = "circle")
    o = Points(x, y, sopts)
    _process_keywords(kvs, p, s, o)
    add(p, s, o)
    ghf(p)
end

function text(x::Real, y::Real, s::AbstractString; kvs...)
    p = _pwinston
    c = DataLabel(x, y, s, halign="left")
    _process_keywords(kvs, p, c)
    add(p, c)
end

spy(S::SparseMatrixCSC) = spy(S, 100, 100)
spy(A::AbstractMatrix, nrS, ncS) = spy(sparse(A), nrS, ncS)
spy(A::AbstractMatrix) = spy(sparse(A))

function plothist(p::FramedPlot, h::@compat(Tuple{Range,Vector}); kvs...)
    c = Histogram(h...)
    add(p, c)

    for (k,v) in kvs
        if k in [:color,:linecolor,:linekind,:linetype,:linewidth]
            style(c, k, v)
        else
            setattr(p, k, v)
        end
    end

    global _pwinston = p
    p
end
plothist(p::FramedPlot, args...; kvs...) = plothist(p::FramedPlot, hist(args...); kvs...)
plothist(args...; kvs...) = plothist(ghf(), args...; kvs...)

# 3x3 gaussian
#_default_kernel2d=[.05 .1 .05; .1 .4 .1; .05 .1 .05]

# 5x5 gaussian
_default_kernel2d=(1.0/273.)*[1.0 4.0 7.0 4.0 1.0;
                             4.0 16. 26. 16. 4.0;
                             7.0 26. 41. 26. 7.0;
                             1.0 4.0 7.0 4.0 1.0;
                             4.0 16. 26. 16. 4.0]

#hist2d
function plothist2d(p::FramedPlot, h::@compat(Tuple{Union{Range,Vector},Union{Range,Vector},Array{Int,2}}); colormap=_current_colormap, smooth=0, kernel=_default_kernel2d, kvs...)
    xr, yr, hdata = h

    for i in 1:smooth
        hdata = conv2(hdata*1.0, kernel)
    end

    clims = (minimum(hdata), maximum(hdata)+1)
    img = data2rgb(hdata, clims, colormap)'
    add(p, Image((xr[1], xr[end]), (yr[1], yr[end]), img;))

    #XXX: check if there is any Image-related named arguments
    setattr(p; kvs...)

    global _pwinston = p
    p
end
plothist2d(p::FramedPlot, args...; kvs...) = plothist2d(p::FramedPlot, hist2d(args...); kvs...)
plothist2d(args...; kvs...) = plothist2d(ghf(), args...; kvs...)

#errorbar
errorbar(args...; kvs...) = errorbar(ghf(), args...; kvs...)
function errorbar(p::FramedPlot, x::AbstractVector, y::AbstractVector; xerr=nothing, yerr=nothing, kvs...)

    xn=length(x)
    yn=length(y)

    if xerr != nothing
        xen = length(xerr)
        if xen == xn
            cx = SymmetricErrorBarsX(x, y, xerr)
        elseif xen == 2xn
            cx = ErrorBarsX(y, x.-xerr[1:xn], x.+xerr[xn+1:xen])
        else
            warn("Dimensions of x and xerr do not match!")
        end
        style(cx; kvs...)
        add(p,cx)
    end

    if yerr != nothing
        yen=length(yerr)
        if yen == yn
            cy = SymmetricErrorBarsY(x, y, yerr)
        elseif yen == 2yn
            cy = ErrorBarsY(x, y.-yerr[1:yn], y.+yerr[yn+1:yen])
        else
            warn("Dimensions of y and yerr do not match!")
        end
        style(cy; kvs...)
        add(p,cy)
    end

    global _pwinston = p
    p
end

function fplot_points(f::Function, xmin::Real, xmax::Real;
        max_recursion::Int=6, min_points::Int=10, tol::Float64=0.01)
    @assert xmin < xmax
    @assert min_points > 1
    @assert max_recursion >= 0

    xs = Float64[]
    ys = Float64[]
    cs = Array(Float64, max_recursion)
    fcs = Array(Float64, max_recursion)
    ls = Array(Int, max_recursion)

    local c::Float64
    local fc::Float64

    function good(a, b, c, fa, fb, fc, tol)
        u = b - a
        fu = fb - fa
        v = c - b
        fv = fc - fb
        n = u*v + fu*fv
        d2 = (u*u + fu*fu)*(v*v + fv*fv)
        n*n > d2*(1. - tol)
    end

    p = linspace(xmin, xmax, min_points)
    q = [f(x) for x in p]

    if max_recursion == 0
        return p, q
    end

    for i = 1:length(p)-1
        a::Float64  = p[i]
        fa::Float64 = q[i]
        c  = p[i+1]
        fc = q[i+1]
        level::Int = 0
        n::Int = 0
        while true
            b::Float64 = 0.5(a + c)
            fb::Float64 = f(b)
            g1::Bool = good(a,b,c,fa,fb,fc,tol)
            g2::Bool = length(xs) > 0 ? good(xs[end],a,b,ys[end],fa,fb,tol) : true
            if (g1 && g2) || level == max_recursion
                push!(xs, a, b)
                push!(ys, fa, fb)
                a = c
                fa = fc
                n == 0 && break
                c = cs[n]
                fc = fcs[n]
                level = ls[n]
                n -= 1
            else
                level += 1
                n += 1
                ls[n] = level
                cs[n] = c
                fcs[n] = fc
                c = b
                fc = fb
            end
        end
    end

    push!(xs, c)
    push!(ys, fc)

    xs, ys
end

function fplot(f::Function, limits, args...; kvs...)
    pargs = []
    fopts = Dict()
    for arg in args
        if typeof(arg) <: AbstractString
            pargs = [arg]
        elseif typeof(arg) <: Integer
            fopts[:min_points] = arg
        elseif typeof(arg) <: FloatingPoint
            fopts[:tol] = arg
        else
            error("unrecognized argument ", arg)
        end
    end
    xmin = limits[1]
    xmax = limits[2]
    x,y = fplot_points(f, xmin, xmax; fopts...)
    plot(x, y, pargs...; kvs...)
end

# bar, barh
ax = @compat Dict{Any,Any}(:bar => :x, :barh => :y)
ax1 = @compat Dict{Any,Any}(:bar => :x1, :barh => :y1)
vert = @compat Dict{Any,Any}(:bar => true, :barh => false)
for fn in (:bar, :barh)
    eval(quote
          function $fn(p::FramedPlot, b::FramedBar, args...; kvs...)
              setattr(b, vertical=$(vert[fn]))
              setattr(p.$(ax[fn]), draw_subticks=false)
              setattr(p.$(ax[fn]), ticks=collect(1.:length(b.h)))
              setattr(p.$(ax1[fn]), ticklabels=b.g)
              add(p, b)
              global _pwinston = p
              p
          end
          function $fn(p::FramedPlot, g::AbstractVector, h::AbstractVector, args...; kvs...)
              b = FramedBar(g, h[:,end], args...; kvs...)
              $fn(p, b, args...; kvs...)
          end
          function $fn(p::FramedPlot, g::AbstractVector, h::AbstractMatrix, args...; kvs...)
              nc = size(h,2)
              barwidth = config_value("FramedBar", "barwidth")/nc
              offsets = barwidth * (nc - 1) * linspace(-.5, .5, nc)
              for c = 1:nc-1
                  b = FramedBar(g, h[:,c], args...; kvs...)
                  setattr(b, offset=offsets[c])
                  setattr(b, barwidth=barwidth)
                  setattr(b, vertical=$(vert[fn]))
                  style(b, fillcolor=default_color(c))
                  style(b, draw_baseline=false)
                  add(p, b)
              end
              b = FramedBar(g, h[:,nc], args...; kvs...)
              setattr(b, offset=offsets[nc])
              setattr(b, barwidth=barwidth)
              style(b, fillcolor=default_color(nc))
              $fn(p, b, args...; kvs...)
          end
          $fn(p::FramedPlot, h::AbstractVecOrMat, args...; kvs...) =
              $fn(p, [1:size(h,1)], h, args...; kvs...)
          $fn(args...; kvs...) = $fn(ghf(), args...; kvs...)
    end )
end

grid(p::FramedPlot, tf::Bool) = (setattr(p.frame, draw_grid=tf); p)
grid(p::FramedPlot) = grid(p, !any(map(x->getattr(x, "draw_grid"), p.frame.objs)))
grid(args...) = grid(_pwinston, args...)

function legend(p::FramedPlot, lab::AbstractVector, args...; kvs...)
    if length(args) > 0 && length(args[1]) == 2 && eltype(args[1]) <: Real
        position = args[1]
        args = args[2:end]
    elseif length(args) > 1 && eltype(args[1:2]) <: Real
        position = args[1:2]
        args = args[3:end]
    else
        position = [0.1, 0.9]
    end
    # TODO: define other legend positions
    plotcomp = getcomponents(p)
    nitems = min(length(lab), length(plotcomp))
    for c in 1:nitems
        setattr(plotcomp[c], label=lab[c])
    end
    add(p, Legend(position..., plotcomp[1:nitems], args...; kvs...))
end
legend(lab::AbstractVector, args...; kvs...) = legend(_pwinston, lab, args...; kvs...)

function timeplot(p::FramedPlot, x::Vector{DateTime}, y::AbstractArray, args...; kvs...)
    limits = datetime2unix([minimum(x), maximum(x)])

    ticks = collect(0.0:0.2:1.0)
    ticklabels = x[round(Int64, ticks * (length(x) - 1) + 1)]
    normalized_x = (datetime2unix(x) - limits[1]) / (limits[2] - limits[1])

    span = @compat Int(x[end] - x[1]) / 1000
    kvs = Dict(kvs)

    if :format in keys(kvs)
        format = kvs[:format]
        delete!(kvs, :format)
    else
        if span > 365 * 24 * 60 * 60 # 1 year
            format = "%Y-%m"
        elseif 365 * 24 * 60 * 60 > span > 30 * 24 * 60 * 60 # 1 month
            format = "%Y-%m-%d"
        elseif 30 * 24 * 60 * 60 > span > 24 * 60 * 60 # 1 day
            format = "%Y-%m-%d\n%H:%M"
        elseif 24 * 60 * 60 > span > 60 * 60 # 1 hour
            format = "%H:%M"
        elseif 60 * 60 > 60 # 1 minute
            format = "%H:%M:%S"
        else
            format = "%H:%M:%S"
        end
    end

    ticklabels = map(d -> strftime(format, datetime2unix(d)), ticklabels)

    setattr(p.x1, :ticklabels, ticklabels)
    setattr(p.x1, :ticks, ticks)
    setattr(p.x1, :ticklabels_style, @compat Dict(:fontsize=>1.5))

    plot(p, normalized_x, y, args...; kvs...)
end

timeplot(x::Vector{DateTime}, y::AbstractArray, args...; kvs...) = timeplot(ghf(), x, y, args...; kvs...)
timeplot(x::Vector{Date}, y::AbstractArray, arg...; kvs...) = timeplot(ghf(), DateTime(x), y, arg...; kvs...)
timeplot(p::FramedPlot, x::Vector{Date}, y::AbstractArray, arg...; kvs...) =
    timeplot(p, DateTime(x), y, arg...; kvs...)
