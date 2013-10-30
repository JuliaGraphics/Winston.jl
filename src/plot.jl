output_surface = Winston.config_value("default","output_surface")
output_surface = symbol(lowercase(get(ENV, "WINSTON_OUTPUT", output_surface)))

import Cairo
using Color

export file
export plot,oplot,semilogx,semilogy,loglog,plothist,oplothist
export spy,imagesc

if output_surface == :gtk
    include("gtk.jl")
elseif output_surface == :tk
    include("tk.jl")
else
    assert(false)
end

global _pwinston

#system functions
file(fname::String) = file(_pwinston, fname)
display() = display(_pwinston)

#main plot function
function plot(args...; overplot=false, kvs...)
    if !overplot
        global _pwinston = FramedPlot()
    end    
    _plot(_pwinston,args...; kvs...)
end

#shortcuts for overplotting
plot(p::FramedPlot,args...; kvs...) = _plot(p, args...; kvs...)
oplot(args...; kvs...) = _plot(_pwinston, args...; kvs...)
oplot(p::FramedPlot,args...; kvs...) = (p2 = deepcopy(p); _plot(p2, args...; kvs...))

#shortcuts for creating log-scale plots
semilogx(args...; kvs...) = plot(args...; xlog=true, kvs...)
semilogy(args...; kvs...) = plot(args...; ylog=true, kvs...)
loglog(args...; kvs...) = plot(args...; xlog=true, ylog=true, kvs...)

#histogram
#XXX: multiple histograms can not be cycled if there is not 2 arguments present
plothist(args...; kvs...)=plot(args...; histogram=true, kvs...)
plothist(x::AbstractVector; kvs...)=plothist(x,[1]; kvs...)
plothist(x::AbstractVector, spec::String; kvs...)=plothist(x,[1], spec; kvs...)

#overplot histograms
plothist(p::FramedPlot,args...; kvs...)=_plot(p,args...; histogram=true, kvs...)
plothist(p::FramedPlot,x::AbstractVector; kvs...)=plothist(p,x,[1]; kvs...)
plothist(p::FramedPlot,x::AbstractVector, spec::String; kvs...)=plothist(p,x,[1], spec; kvs...)

oplothist(args...; kvs...)=plothist(args...; overplot=true, kvs...)
oplothist(p::FramedPlot,args...; kvs...)=plothist(p,args...; overplot=true, kvs...)


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

_plot(p::FramedPlot, y; kvs...) = _plot(p, 1:length(y), y; kvs...)
_plot(p::FramedPlot, y, spec::String; kvs...) = _plot(p, 1:length(y), y, spec; kvs...)
function _plot(p::FramedPlot, x, y, args...; histogram=false, kvs...)
    args = {args...}

    while true
        sopts = [ :linekind => "solid" ] # TODO:cycle colors
        if length(args) > 0 && typeof(args[1]) <: String
            merge!(sopts, _parse_style(shift!(args)))
        end

        #Case 1: Histogram
        if histogram
            if length(y)==1 && y[1]==1
                c=Histogram(hist(x)...,sopts)
            elseif length(y)==1
                c=Histogram(hist(x,y[1])...,sopts)
            else
                c=Histogram(hist(x,y)...,sopts)
            end
            
            #Adding style from named variables
            for (k,v) in kvs
                if in(k,[:linekind,:color,:fillcolor,:linecolor,:linewidth])
                    style(c,k,v)
                end
            end

        #Case 2: Last object to plot
        elseif length(args)==0

            #Assume curve and overwrite with points if :symbolkind is present
            c=Curve(x,y,sopts)
            for (k,v) in kvs
                if k==:symbolkind
                    c = Points(x, y, sopts)
                    break
                end
            end

            #Setting style for the last object from named variables
            for (k,v) in kvs
                if k in [:linekind,:symbolkind,:color,:fillcolor,:linecolor,:linewidth,:symbolsize]
                    style(c, k, v)
                end
            end

        #Case 3: Symbols
        elseif haskey(sopts, :symbolkind)
            c=Points(x,y,sopts)

        #Case 4: Curve
        else
            c = Curve(x, y, sopts)
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
    display(p)

    global _pwinston = p
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
