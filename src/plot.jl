output_surface = Winston.config_value("default","output_surface")
output_surface = symbol(lowercase(get(ENV, "WINSTON_OUTPUT", output_surface)))

import Cairo
using Color

export file,
       imagesc,
       loglog,
       oplot,
       plot,
       plothist,
       semilogx,
       semilogy,
       spy

if output_surface == :gtk
    include("gtk.jl")
elseif output_surface == :tk
    include("tk.jl")
else
    assert(false)
end

_pwinston = FramedPlot()

#system functions
file(fname::String) = file(_pwinston, fname)
display() = display(_pwinston)

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

    while true
        sopts = [ :linekind => "solid" ] # TODO:cycle colors
        if length(args) > 0 && typeof(args[1]) <: String
            merge!(sopts, _parse_style(shift!(args)))
        end

        #Case 1: Last object to plot
        if length(args) == 0

            #Assume curve and overwrite with points if :symbolkind is present
            c=Curve(x,y,sopts)
            for (k,v) in kvs
                if k == :symbolkind
                    c = Points(x, y, sopts)
                    break
                end
            end

            #Setting kind and color for the last object from named variables
            for (k,v) in kvs
                if k in [:linekind, :symbolkind, :color, :fillcolor, :linecolor]
                    style(c, k, v)
                end
            end

        #Case 2: Symbols
        elseif haskey(sopts, :symbolkind)
            c = Points(x,y,sopts)

        #Case 3: Curve
        else
            c = Curve(x, y, sopts)
        end

        #Setting width & size from named variables
        for (k,v) in kvs
            if k in [:linewidth, :symbolsize]
                style(c, k, v)
            end
        end
        add(p, c)


        length(args) == 0 && break
        length(args) == 1 && error("wrong number of arguments")
        x = shift!(args)
        y = shift!(args)
    end

    for (k,v) in kvs
        setattr(p, k, v)
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

#Histogram
function plothist(p::FramedPlot, x, y, args...; kvs...)
    _plothist(p, x, y, args...; kvs...)
    display(p)
    p
end
plothist(args...; kvs...) = plothist(FramedPlot(), args...; kvs...)

# shortcut for overplotting
oplothist(args...; kvs...) = plothist(_pwinston, args...; kvs...)

function _plothist(p::FramedPlot, args...; kvs...)
    args = {args...}
    while true
        length(args) == 0 && break
        y = 1
        x = shift!(args)

        sopts = [ :linekind => "solid" ] # TODO:cycle colors

        #Check if y is presented (vector/range or nbins)
        if length(args) > 0 && !(typeof(args[1]) <: String) 
            y = shift!(args)
        end

        #Check if style option is presented
        if length(args) > 0 && typeof(args[1]) <: String
            merge!(sopts, _parse_style(shift!(args)))    
        end

        if y == 1
            c = Histogram(hist(x)..., sopts)
        else
            c = Histogram(hist(x,y)..., sopts)
        end

        #Setting width from named variables
        for (k,v) in kvs
            if k in [:linewidth]
                style(c, k, v)
            end
        end
        
        #Setting kind and color for the last object from named variables
        if length(args) == 0
            for (k,v) in kvs
                if k in [:linekind, :color, :fillcolor, :linecolor]
                    style(c, k, v)
                end
            end
        end
        add(p, c)
    end

    for (k,v) in kvs
        setattr(p, k, v)
    end

    global _pwinston = p
    p
end            
