output_surface = Winston.config_value("default","output_surface")
output_surface = symbol(lowercase(get(ENV, "WINSTON_OUTPUT", output_surface)))

import Cairo
using Color

export imagesc, plot, semilogx, semilogy, loglog
export file, spy, plothist

if output_surface == :gtk
    include("gtk.jl")
elseif output_surface == :tk
    include("tk.jl")
else
    assert(false)
end

function plot(args...; kvs...)
    p = FramedPlot()
    _plot(p, args...; kvs...)
end

function semilogx(args...; kvs...)
    p = FramedPlot()
    setattr(p, "xlog", true)
    _plot(p, args...; kvs...)
end

function semilogy(args...; kvs...)
    p = FramedPlot()
    setattr(p, "ylog", true)
    _plot(p, args...; kvs...)
end

function loglog(args...; kvs...)
    p = FramedPlot()
    setattr(p, "xlog", true)
    setattr(p, "ylog", true)
    _plot(p, args...; kvs...)
end

const chartokens = [
    '-' => {:linestyle => "solid"},
    ':' => {:linestyle => "dotted"},
    ';' => {:linestyle => "dotdashed"},
    '+' => {:symboltype => "plus"},
    'o' => {:symboltype => "circle"},
    '*' => {:symboltype => "asterisk"},
    '.' => {:symboltype => "dot"},
    'x' => {:symboltype => "cross"},
    's' => {:symboltype => "square"},
    'd' => {:symboltype => "diamond"},
    '^' => {:symboltype => "triangle"},
    'v' => {:symboltype => "down-triangle"},
    '>' => {:symboltype => "right-triangle"},
    '<' => {:symboltype => "left-triangle"},
    'y' => {:color => "yellow"},
    'm' => {:color => "magenta"},
    'c' => {:color => "cyan"},
    'r' => {:color => "red"},
    'g' => {:color => "green"},
    'b' => {:color => "blue"},
    'w' => {:color => "white"},
    'k' => {:color => "black"},
]

function _parse_style(spec::String)
    style = Dict()

    for (k,v) in [ "--" => "dashed", "-." => "dotdashed" ]
        splitspec = split(spec, k)
        if length(splitspec) > 1
            style[:linestyle] = v
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

_plot(p::FramedPlot, y; kvs...) = _plot(p, 1:length(y), y; kvs...)
_plot(p::FramedPlot, y, spec::String; kvs...) = _plot(p, 1:length(y), y, spec; kvs...)
function _plot(p::FramedPlot, x, y, args...; kvs...)
    args = {args...}
    while true
        style = [ :linestyle => "solid" ] # TODO:cycle colors
        if length(args) > 0 && typeof(args[1]) <: String
            merge!(style, _parse_style(shift!(args)))
        end
        if haskey(style, :linestyle)
            add(p, Curve(x, y, style))
        elseif haskey(style, :symboltype)
            add(p, Points(x, y, style))
        end
        length(args) == 0 && break
        length(args) == 1 && error("wrong number of arguments")
        x = shift!(args)
        y = shift!(args)
    end
    for (k,v) in kvs
        setattr(p, k, v)
    end
    display(p)
    p
end

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
    display(p)
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

function plothist(h::(Range,Vector))
    p = FramedPlot()
    add(p, Histogram(h...))
    display(p)
end

plothist(x::AbstractVector, nbins) = plothist(hist(x,nbins))
plothist(x::AbstractVector) = plothist(hist(x))
