output_surface = Winston.config_value("default","output_surface")
output_surface = Base.symbol(lowercase(get(ENV, "WINSTON_OUTPUT", output_surface)))

#module Plot

#using Winston
import Cairo
using Color

export imagesc, plot, semilogx, semilogy, loglog
export file

if output_surface == :gtk
    include("gtk.jl")
elseif output_surface == :tk
    include("tk.jl")
else
    assert(false)
end

function plot(args...)
    p = FramedPlot()
    _plot(p, args...)
end

function semilogx(args...)
    p = FramedPlot()
    setattr(p, "xlog", true)
    _plot(p, args...)
end

function semilogy(args...)
    p = FramedPlot()
    setattr(p, "ylog", true)
    _plot(p, args...)
end

function loglog(args...)
    p = FramedPlot()
    setattr(p, "xlog", true)
    setattr(p, "ylog", true)
    _plot(p, args...)
end

const chartokens = [
    '-' => {"linestyle" => "solid"},
    ':' => {"linestyle" => "dotted"},
    ';' => {"linestyle" => "dotdashed"},
    '+' => {"symboltype" => "plus"},
    'o' => {"symboltype" => "circle"},
    '*' => {"symboltype" => "asterisk"},
    '.' => {"symboltype" => "dot"},
    'x' => {"symboltype" => "cross"},
    's' => {"symboltype" => "square"},
    'd' => {"symboltype" => "diamond"},
    '^' => {"symboltype" => "triangle"},
    'v' => {"symboltype" => "down-triangle"},
    '>' => {"symboltype" => "right-triangle"},
    '<' => {"symboltype" => "left-triangle"},
    'y' => {"color" => "yellow"},
    'm' => {"color" => "magenta"},
    'c' => {"color" => "cyan"},
    'r' => {"color" => "red"},
    'g' => {"color" => "green"},
    'b' => {"color" => "blue"},
    'w' => {"color" => "white"},
    'k' => {"color" => "black"},
]

function _parse_style(spec::String)
    style = Dict()

    for (k,v) in [ "--" => "dashed", "-." => "dotdashed" ]
        splitspec = split(spec, k)
        if length(splitspec) > 1
            style["linestyle"] = v
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

function args2array(args...)
    n = length(args)
    a = cell(n)
    for i = 1:n
        a[i] = args[i]
    end
    a
end

function _plot(p::FramedPlot, args...)
    compose_plot(p, args...)
    display(p)
end

function compose_plot(p::FramedPlot, args...)
    args = args2array(args...)
    n = length(args)
    @assert n > 0
    if n == 1
        y = args[1]
        x = 1:length(y)
        add(p, Curve(x,y))
        return p
    end
    while length(args) > 0
        x = shift!(args)
        if typeof(x) <: String
            # TODO
        else
            y = shift!(args)
            style = [ "linestyle" => "solid" ] # TODO:cycle colors
            if length(args) > 0 && typeof(args[1]) <: String
                a = shift!(args)
                if a == "xlabel" || a == "ylabel" || a == "title"
                    setattr(p, a, shift!(args))
                else
                    style = _parse_style(a)
                end
            end
            if haskey(style, "linestyle")
                add(p, Curve(x, y, style))
            end
            if haskey(style, "symboltype")
                add(p, Points(x, y, style))
            end
        end
    end
    p
end

typealias Interval (Real,Real)

function data2rgb{T<:Real}(data::AbstractArray{T,2}, limits::Interval, colormap)
    img = similar(data, Uint32)
    ncolors = length(colormap)
    for i = 1:length(data)
        idx = iceil(ncolors*(data[i] - limits[1])/(limits[2] - limits[1]))
        if idx < 1 idx = 1 end
        if idx > ncolors idx = ncolors end
        img[i] = colormap[idx]
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

imagesc(xrange, yrange, data) = imagesc(xrange, yrange, data, (min(data),max(data)))
imagesc(data) = ((h, w) = size(data); imagesc((0,w), (0,h), data))

#end # module
