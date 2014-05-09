
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

#system functions
file(fname::String, args...; kvs...) = file(_pwinston, fname, args...; kvs...)
const savefig = file

for f in (:xlabel,:ylabel,:title)
    @eval $f(s::String) = (setattr(_pwinston, $f=s); _pwinston)
end
for (f,k) in ((:xlim,:xrange),(:ylim,:yrange))
    @eval $f(a, b) = (setattr(_pwinston, $k=(a,b)); _pwinston)
    @eval $f(a) = (setattr(_pwinston, $k=(a[1],a[2])); _pwinston)
    @eval $f() = $k(limits(_pwinston))
end

const chartokens = [
    '-' => {:linekind => "solid"},
    ':' => {:linekind => "dotted"},
    ';' => {:linekind => "dotdashed"},
    '+' => {:symbolkind => "plus"},
    'o' => {:symbolkind => "circle"},
    '*' => {:symbolkind => "asterisk"},
    '.' => {:symbolkind => "dot"},
    'x' => {:symbolkind => "cross"},
    's' => {:symbolkind => "square"},
    'd' => {:symbolkind => "diamond"},
    '^' => {:symbolkind => "triangle"},
    'v' => {:symbolkind => "down-triangle"},
    '>' => {:symbolkind => "right-triangle"},
    '<' => {:symbolkind => "left-triangle"},
    'y' => {:color => "yellow"},
    'm' => {:color => "magenta"},
    'c' => {:color => "cyan"},
    'r' => {:color => "red"},
    'g' => {:color => "green"},
    'b' => {:color => "blue"},
    'w' => {:color => "white"},
    'k' => {:color => "black"},
]

function _parse_spec(spec::String)
    try
        return { :color => Color.color(spec) }
    end

    style = Dict()

    for (k,v) in [ "--" => "dashed", "-." => "dotdashed" ]
        splitspec = split(spec, k)
        if length(splitspec) > 1
            style[:linekind] = v
            spec = join(splitspec)
        end
    end

    for char in spec
        if haskey(chartokens, char)
            for (k,v) in chartokens[char]
                style[k] = v
            end
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

typealias PlotArg Union(String,AbstractVector,AbstractMatrix)

isrowvec(x::AbstractArray) = ndims(x) == 2 && size(x,1) == 1 && size(x,2) > 1

function plot(p::FramedPlot, args::PlotArg...; kvs...)
    args = {args...}
    components = {}
    color_idx = 0

    default_style = Dict()
    attr = {}
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
            push!(attr, (k,v))
        end
    end

    i = 1
    while length(args) > 0
        local x, y, ys

        if length(args) == 1 || typeof(args[2]) <: String
            elt = eltype(args[1])
            if elt <: Complex
                z = shift!(args)
                x = real(z)
                y = imag(z)
            elseif elt <: Real
                y = shift!(args)
                x = 1:(isrowvec(y) ? size(y,2) : size(y,1))
            else
                error("eltype of argument #$i is not Real or Complex")
            end
            i += 1
        else
            x = shift!(args)
            eltype(x) <: Real || error("eltype of argument #$i is not Real")
            i += 1
            y = shift!(args)
            eltype(y) <: Real || error("eltype of argument #$i is not Real")
            i += 1
        end

        sopts = copy(default_style)
        if length(args) > 0 && typeof(args[1]) <: String
            merge!(sopts, _parse_spec(shift!(args)))
        end
        no_color = !haskey(sopts, :color)
        add_curve = haskey(sopts, :linekind) || !haskey(sopts, :symbolkind)
        add_points = haskey(sopts, :symbolkind)

        x = vec(x)
        if size(y,1) > 1 && size(y,2) > 1
            ys = { sub(y,:,j) for j = 1:size(y,2) }
        else
            ys = { vec(y) }
        end

        n = length(x)
        for y in ys
            length(y) == n || warn("vector length mismatch")
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

typealias Interval (Real,Real)

function data2rgb{T<:Real}(data::AbstractArray{T}, limits::Interval, colormap::Array{Uint32,1})
    img = similar(data, Uint32)
    ncolors = length(colormap)
    limlower = limits[1]
    limscale = ncolors/(limits[2]-limits[1])
    for i = 1:length(data)
        datai = data[i]
        if isfinite(datai)
            idxr = limscale*(datai - limlower)
            idx = itrunc(idxr)
            idx += idxr > convert(T, idx)
            if idx < 1 idx = 1 end
            if idx > ncolors idx = ncolors end
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
colormap(c::Array{Uint32,1}) = (global _current_colormap = c; nothing)
colormap{C<:ColorValue}(cs::Array{C,1}) =
    colormap(Uint32[convert(RGB24,c) for c in cs])
function colormap(name::String, n::Int=256)
    if name == "jet"
        colormap([jetrgb(x) for x in linspace(0.,1.,n)])
    else
        colormap(Color.colormap(name, n))
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
                 s::Union(Real,AbstractVecOrMat), c::AbstractVecOrMat,
                 spec::ASCIIString="o"; kvs...)
    if typeof(s) <: Real
        s = fill(s, size(x)...)
    end
    if eltype(c) <: Real
        c = data2rgb(c, extrema(c), _current_colormap)
    elseif !(eltype(c) <: ColorValue)
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

function text(x::Real, y::Real, s::String; kvs...)
    p = _pwinston
    c = DataLabel(x, y, s, halign="left")
    _process_keywords(kvs, p, c)
    add(p, c)
end

spy(S::SparseMatrixCSC) = spy(S, 100, 100)
spy(A::AbstractMatrix, nrS, ncS) = spy(sparse(A), nrS, ncS)
spy(A::AbstractMatrix) = spy(sparse(A))

function plothist(p::FramedPlot, h::(Range,Vector); kvs...)
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

quartileboxes(args...; kvs...) = quartileboxes(ghf(), args...; kvs...)

function quartileboxes(p::FramedPlot, h::Matrix;kvs...)
    for i=1:size(h,2)
        b = QuartileBoxes(h[:,i];kvs...)
        b.position = 1.1*b.width*i
        quartileboxes(p,b;kvs...)
    end
    p
end

function quartileboxes(p::FramedPlot, h::Vector;kvs...)
    b = QuartileBoxes(h;kvs...)
    quartileboxes(p,b;kvs...)
end

function quartileboxes(p::FramedPlot, h::(Float64,(Float64,Float64),Vector);kvs...)
    b = QuartileBoxes(h...;kvs...)
    quartileboxes(p,b;kvs...)
end

function quartileboxes(p::FramedPlot, b::QuartileBoxes;kvs...)
    #messy...
    dd = args2dict(kvs...)
    if :position in keys(dd)
        setattr(b,:position, dd[:position])
        b.position = dd[:position]
    end
    add(p,b)
    for (k,v) in kvs
        if k in [:color,:linecolor,:linekind,:linetype,:linewidth]
            style(b, k, v)
        else
            setattr(p, k, v)
        end
    end

    global _pwinston = p
    p
end

# 3x3 gaussian
#_default_kernel2d=[.05 .1 .05; .1 .4 .1; .05 .1 .05]

# 5x5 gaussian
_default_kernel2d=(1.0/273.)*[1.0 4.0 7.0 4.0 1.0;
                             4.0 16. 26. 16. 4.0;
                             7.0 26. 41. 26. 7.0;
                             1.0 4.0 7.0 4.0 1.0;
                             4.0 16. 26. 16. 4.0]                 

#hist2d
function plothist2d(p::FramedPlot, h::(Union(Range,Vector),Union(Range,Vector),Array{Int,2}); colormap=_current_colormap, smooth=0, kernel=_default_kernel2d, kvs...)
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
        if typeof(arg) <: String
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
