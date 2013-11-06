output_surface = Winston.config_value("default","output_surface")
output_surface = symbol(lowercase(get(ENV, "WINSTON_OUTPUT", output_surface)))

export errorbar,
       file,
       imagesc,
       loglog,
       oplot,
       oplothist,
       plot,
       plothist,
       semilogx,
       semilogy,
       spy,
       title,
       xlabel,
       xlim,
       ylabel,
       ylim

type WinstonDisplay <: Display end
pushdisplay(WinstonDisplay())

import Base.display
if output_surface == :gtk
    include("gtk.jl")
    display(::WinstonDisplay, p::PlotContainer) = gtk(p)
elseif output_surface == :tk
    include("tk.jl")
    display(::WinstonDisplay, p::PlotContainer) = tk(p)
else
    assert(false)
end

_pwinston = FramedPlot()

#system functions
file(fname::String, args...; kvs...) = file(_pwinston, fname, args...; kvs...)
display() = display(_pwinston)

for f in (:xlabel,:ylabel,:title)
    @eval $f(s::String) = (setattr(_pwinston, $f=s); _pwinston)
end
for (f,k) in ((:xlim,:xrange),(:ylim,:yrange))
    @eval $f(a, b) = (setattr(_pwinston, $k=(a,b)); _pwinston)
    @eval $f(a) = (setattr(_pwinston, $k=(a[1],a[2])); _pwinston)
end

#shortcuts for creating log-scale plots
semilogx(args...; kvs...) = plot(args...; xlog=true, kvs...)
semilogy(args...; kvs...) = plot(args...; ylog=true, kvs...)
loglog(args...; kvs...) = plot(args...; xlog=true, ylog=true, kvs...)

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
        end
    end

    style
end

function default_color(i::Int)
    cs = [0x000000, 0xED2C30, 0x008C46, 0x1859A9,
          0xF37C21, 0x652B91, 0xA11C20, 0xB33794]
    cs[mod1(i,length(cs))]
end

function plot(p::FramedPlot, args...; kvs...)
    args = {args...}
    components = {}
    i = 0

    while length(args) > 0
        local x, y, sopts

        if length(args) == 1 || typeof(args[2]) <: String
            y = shift!(args)
            x = 1:length(y)
        else
            x = shift!(args)
            y = shift!(args)
        end

        if length(args) > 0 && typeof(args[1]) <: String
            sopts = _parse_spec(shift!(args))
        else
            sopts = {:linekind => "solid"}
        end
        if !haskey(sopts, :color)
            i += 1
            sopts[:color] = default_color(i)
        end

        if haskey(sopts, :linekind) || !haskey(sopts, :symbolkind)
            push!(components, Curve(x, y, sopts))
        end
        if haskey(sopts, :symbolkind)
            push!(components, Points(x, y, sopts))
        end
    end

    for (k,v) in kvs
        if k in [:linekind,:symbolkind,:color,:linecolor,:linewidth,:symbolsize]
            for c in components
                style(c, k, v)
            end
        else
            setattr(p, k, v)
        end
    end

    for c in components
        add(p, c)
    end

    global _pwinston = p
    p
end
plot(args...; kvs...) = plot(FramedPlot(), args...; kvs...)

# shortcut for overplotting
oplot(args...; kvs...) = plot(_pwinston, args...; kvs...)

typealias Interval (Real,Real)

function data2rgb{T<:Real}(data::AbstractArray{T,2}, limits::Interval, colormap)
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

JetColormap() = Uint32[ convert(RGB24,jetrgb(i/256)) for i = 1:256 ]

_default_colormap = JetColormap()

GrayColormap() = Uint32[ convert(RGB24,RGB(i/255,i/255,i/255)) for i = 0:255 ]

function imagesc{T<:Real}(xrange::Interval, yrange::Interval, data::AbstractArray{T,2}, clims::Interval)
    p = FramedPlot()
    setattr(p, "xrange", xrange)
    setattr(p, "yrange", reverse(yrange))
    img = data2rgb(data, clims, _default_colormap)
    add(p, Image(xrange, reverse(yrange), img))
    p
end

imagesc(xrange, yrange, data) = imagesc(xrange, yrange, data, (min(data),max(data)+1))
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
plothist(args...; kvs...) = plothist(FramedPlot(), args...; kvs...)

# shortcut for overplotting
oplothist(args...; kvs...) = plothist(_pwinston, args...; kvs...)

#errorbar
errorbar(args...; kvs...) = errorbar(_pwinston, args...; kvs...)
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

