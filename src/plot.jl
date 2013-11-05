output_surface = Winston.config_value("default","output_surface")
output_surface = symbol(lowercase(get(ENV, "WINSTON_OUTPUT", output_surface)))

import Cairo
using Color

export file,
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
       ylabel

if output_surface == :gtk
    include("gtk.jl")
elseif output_surface == :tk
    include("tk.jl")
else
    assert(false)
end

_pwinston = FramedPlot()

#system functions
file(fname::String, args...; kvs...) = file(_pwinston, fname, args...; kvs...)
display() = display(_pwinston)

for f in (:xlabel,:ylabel,:title)
    @eval $f(s::String) = (setattr(_pwinston, $f=s); display(_pwinston))
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

function _parse_style(spec::String)
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

plot(p::FramedPlot, y; kvs...) = plot(p, 1:length(y), y; kvs...)
plot(p::FramedPlot, y, spec::String; kvs...) = plot(p, 1:length(y), y, spec; kvs...)
function _plot(p::FramedPlot, x, y, args...; kvs...)
    args = {args...}
    components = {}

    while true
        sopts = [ :linekind => "solid" ] # TODO:cycle colors
        if length(args) > 0 && typeof(args[1]) <: String
            merge!(sopts, _parse_style(shift!(args)))
        end

        if haskey(sopts, :symbolkind)
            c = Points(x, y, sopts)
        else
            c = Curve(x, y, sopts)
        end
        push!(components, c)
        add(p, c)

        length(args) == 0 && break
        length(args) == 1 && error("wrong number of arguments")
        x = shift!(args)
        y = shift!(args)
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

    global _pwinston = p
    p
end

function plot(p::FramedPlot, x, y, args...; kvs...)
    _plot(p, x, y, args...; kvs...)
    display(p)
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
    display(p)
    p
end
plothist(p::FramedPlot, args...; kvs...) = plothist(p::FramedPlot, hist(args...); kvs...)
plothist(args...; kvs...) = plothist(FramedPlot(), args...; kvs...)

# shortcut for overplotting
oplothist(args...; kvs...) = plothist(_pwinston, args...; kvs...)

