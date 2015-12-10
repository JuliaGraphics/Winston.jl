module Winston

using Cairo
using Colors
if VERSION < v"0.4.0-dev+3275"
    importall Base.Graphics
else
    importall Graphics
end
using IniFile
using Compat
using Dates
isdefined(Base, :Libc) && (strftime = Libc.strftime)
isdefined(Base, :Dates) && (datetime2unix = Dates.datetime2unix)

export
    bar,
    barh,
    closefig,
    closeall,
    colormap,
    errorbar,
    figure,
    fplot,
    gcf,
    hold,
    imagesc,
    loglog,
    oplot,
    plot,
    plothist,
    plothist2d,
    savefig,
    scatter,
    semilogx,
    semilogy,
    spy,
    stem,
    text,
    title,
    timeplot,
    xlabel,
    xlim,
    ylabel,
    ylim

export
    # FramedArray
    FramedPlot,
    Plot,
    Table,

    Curve,
    FillAbove,
    FillBelow,
    FillBetween,
    FramedBar,
    Histogram,
    Image,
    Legend,
    LineX,
    LineY,
    PlotInset,
    PlotLabel,
    Points,
    Slope,
    Stems,
    SymmetricErrorBarsX,
    SymmetricErrorBarsY,

    add,
    file,
    getattr,
    setattr,
    style,
    svg,
    
    getcomponents,
    rmcomponents,
    grid,
    legend

import Base: copy,
    display,
    get,
    getindex,
    isempty,
    setindex!,
    show,
    writemime

export get_context, device_to_data, data_to_device

if VERSION < v"0.3-"
    typealias AbstractVecOrMat{T}(@compat Union{AbstractVector{T}, AbstractMatrix{T}})
    extrema(x) = (minimum(x),maximum(x))
    Base.push!(x, a, b) = (push!(x, a); push!(x, b))
elseif VERSION < v"0.4-"
    macro Dict(pairs...)
        Expr(:dict, pairs...)
    end
else
    macro Dict(pairs...)
        Expr(:call, :Dict, pairs...)
    end
end

type WinstonException <: Exception
    msg::ByteString
end

abstract HasAttr
abstract HasStyle <: HasAttr
abstract PlotComponent <: HasStyle
abstract PlotContainer <: HasAttr

typealias PlotAttributes Associative # TODO: does Associative need {K,V}?

include("config.jl")
include("geom.jl")
include("renderer.jl")
include("paint.jl")

# utils -----------------------------------------------------------------------

function args2dict(args...; kvs...)
    opts = Dict{Symbol,Any}()
    iter = start(args)
    while !done(args, iter)
        arg, iter = next(args, iter)
        if typeof(arg) <: Associative
            for (k,v) in arg
                opts[symbol(k)] = v
            end
        elseif typeof(arg) <: Tuple
            opts[symbol(arg[1])] = arg[2]
        else
            val, iter = next(args, iter)
            opts[symbol(arg)] = val
        end
    end
    for (k,v) in kvs
        opts[k] = v
    end
    opts
end

# NOTE: these are not standard, since where a coordinate falls on the screen
# depends on the current transformation.
lowerleft(bb::BoundingBox) = Point(bb.xmin, bb.ymin)
upperleft(bb::BoundingBox) = Point(bb.xmin, bb.ymax)
lowerright(bb::BoundingBox) = Point(bb.xmax, bb.ymin)
upperright(bb::BoundingBox) = Point(bb.xmax, bb.ymax)

function bounds_within(x, y, window::BoundingBox)
    xmin, xmax, ymin, ymax = NaN, NaN, NaN, NaN
    for i = 1:min(length(x),length(y))
        xi = x[i]
        yi = y[i]
        if (window.xmin < xi < window.xmax) && (window.ymin < yi < window.ymax)
            xmin = min(xmin, xi)
            xmax = max(xmax, xi)
            ymin = min(ymin, yi)
            ymax = max(ymax, yi)
        end
    end
    BoundingBox(xmin, xmax, ymin, ymax)
end

# relative size ---------------------------------------------------------------

@compat typealias Box Union{BoundingBox,Rectangle}

function _size_relative(relsize, bbox::Box)
    w = width(bbox)
    h = height(bbox)
    yardstick = sqrt(8.) * w * h / (w + h)
    return 0.01 * relsize * yardstick
end

function _fontsize_relative(relsize, bbox::Box, device_bbox::Box)
    devsize = _size_relative(relsize, bbox)
    fontsize_min = config_value("default", "fontsize_min")
    devsize_min = _size_relative(fontsize_min, device_bbox)
    return max(devsize, devsize_min)
end

# PlotContext -------------------------------------------------------------

type PlotContext
    draw::Renderer
    dev_bbox::BoundingBox
    data_bbox::BoundingBox
    xlog::Bool
    ylog::Bool
    xflipped::Bool
    yflipped::Bool
    geom::AbstractProjection2
    plot_geom::AbstractProjection2
    paintc::PaintContext

    function PlotContext(device::Renderer, dev::BoundingBox, data::Rectangle, proj::AbstractProjection2, xlog=false, ylog=false)
        xflipped = data.x0 > data.x1
        yflipped = data.y0 > data.y1
        paintc = PaintContext(device, _size_relative(1,dev), _fontsize_relative(0,dev,boundingbox(device)))
        new(
            device,
            dev,
            BoundingBox(data),
            xlog,
            ylog,
            xflipped,
            yflipped,
            proj,
            PlotGeometry(Rectangle(0,1,0,1), dev),
            paintc
       )
    end
end

function _get_context(device::Renderer, ext_bbox::BoundingBox, pc::PlotContainer)
    for (key,val) in config_options("defaults")
        set(device, key, val)
    end
    ext_bbox *= 1 - getattr(pc, "page_margin")
    if hasattr(pc, "title")
        offset = _size_relative(getattr(pc,"title_offset"), ext_bbox)
        fontsize = _fontsize_relative(
            getattr(pc,"title_style")["fontsize"], ext_bbox, boundingbox(device))
        ext_bbox = deform(ext_bbox, 0, 0, 0, -offset-fontsize)
    end
    int_bbox = interior(pc, device, ext_bbox)
    invoke(compose_interior, (PlotContainer,Renderer,BoundingBox), pc, device, int_bbox)
    ret = _context1(pc, device, int_bbox)
    ret
end

function device_to_data(ctx::PlotContext, x::Real, y::Real)
    deproject(ctx.geom, x, y)
end

function data_to_device{T<:Real}(ctx::PlotContext, x::(@compat Union{T,AbstractArray{T}}), y::(@compat Union{T,AbstractArray{T}}))
    project(ctx.geom, x, y)
end

# Legend ----------------------------------------------------------------------

type Legend <: PlotComponent
    attr::PlotAttributes
    x
    y
    components::Array{PlotComponent,1}

    function Legend(x, y, components, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.x = x
        self.y = y
        self.components = components
        self
    end
end

_kw_rename(::Legend) = @Dict(
    :face      => :fontface,
    :size      => :fontsize,
    :angle     => :textangle,
    :halign    => :texthalign,
    :valign    => :textvalign,
)

function make(self::Legend, context::PlotContext)
    key_pos = project(context.plot_geom, self.x, self.y)
    key_width = _size_relative(getattr(self, "key_width"), context.dev_bbox)
    key_height = _size_relative(getattr(self, "key_height"), context.dev_bbox)
    key_hsep = _size_relative(getattr(self, "key_hsep"), context.dev_bbox)
    key_vsep = _size_relative(getattr(self, "key_vsep"), context.dev_bbox)

    halign = kw_get(self, :texthalign)
    if halign == "left"
        text_pos = Point(key_pos[1]+key_width/2+key_hsep, key_pos[2])
    else
        text_pos = Point(key_pos[1]-key_width/2-key_hsep, key_pos[2])
    end
    bbox = BoundingBox(key_pos[1]-key_width/2, key_pos[1]+key_width/2,
                       key_pos[2]-key_height/2, key_pos[2]+key_height/2)
    dp = Vec2(0., -(key_vsep + key_height))

    objs = GroupPainter(getattr(self,:style))
    for comp in self.components
        s = getattr(comp, "label", "")
        t = TextPainter(text_pos, s; halign=halign)
        push!(objs, t)
        push!(objs, make_key(comp,bbox))
        text_pos = text_pos + dp
        bbox = shift(bbox, dp.x, dp.y)
    end
    objs
end

# ErrorBars --------------------------------------------------------------------

abstract ErrorBar <: PlotComponent

_kw_rename(::ErrorBar) = @Dict(
    :color => :linecolor,
    :width => :linewidth,
    :kind => :linekind,
)

type ErrorBarsX <: ErrorBar
    attr::PlotAttributes
    y
    lo
    hi

    function ErrorBarsX(y, lo, hi, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.y = y
        self.lo = lo
        self.hi = hi
        self
    end
end

limits(self::ErrorBarsX, window::BoundingBox) =
    bounds_within(self.lo, self.y, window) +
    bounds_within(self.hi, self.y, window)

function make(self::ErrorBarsX, context)
    l = _size_relative(getattr(self, "barsize"), context.dev_bbox)
    objs = GroupPainter(getattr(self,:style))
    for i = 1:length(self.y)
        p = project(context.geom, self.lo[i], self.y[i])
        q = project(context.geom, self.hi[i], self.y[i])
        l0 = LinePainter(Point(p[1],p[2]), Point(q[1],q[2]))
        l1 = LinePainter(Point(p[1],p[2]-l), Point(p[1],p[2]+l))
        l2 = LinePainter(Point(q[1],q[2]-l), Point(q[1],q[2]+l))
        push!(objs, l0)
        push!(objs, l1)
        push!(objs, l2)
    end
    objs
end

type ErrorBarsY <: ErrorBar
    attr::PlotAttributes
    x
    lo
    hi

    function ErrorBarsY(x, lo, hi, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.x = x
        self.lo = lo
        self.hi = hi
        self
    end
end

limits(self::ErrorBarsY, window::BoundingBox) =
    bounds_within(self.x, self.lo, window) +
    bounds_within(self.x, self.hi, window)

function make(self::ErrorBarsY, context)
    objs = GroupPainter(getattr(self,:style))
    l = _size_relative(getattr(self, "barsize"), context.dev_bbox)
    for i = 1:length(self.x)
        p = project(context.geom, self.x[i], self.lo[i])
        q = project(context.geom, self.x[i], self.hi[i])
        l0 = LinePainter(Point(p[1],p[2]), Point(q[1],q[2]))
        l1 = LinePainter(Point(p[1]-l,p[2]), Point(p[1]+l,p[2]))
        l2 = LinePainter(Point(q[1]-l,q[2]), Point(q[1]+l,q[2]))
        push!(objs, l0)
        push!(objs, l1)
        push!(objs, l2)
    end
    objs
end

function SymmetricErrorBarsX(x, y, err, args...)
    xlo = x - err
    xhi = x + err
    return ErrorBarsX(y, xlo, xhi, args...)
end

function SymmetricErrorBarsY(x, y, err, args...)
    ylo = y - err
    yhi = y + err
    return ErrorBarsY(x, ylo, yhi, args...)
end

# Inset -----------------------------------------------------------------------

abstract _Inset <: PlotComponent

function render(self::_Inset, context::PlotContext)
    region = boundingbox(self, context)
    compose_interior(self.plot, context.draw, region)
end

type DataInset <: _Inset
    plot_limits::BoundingBox
    plot::PlotContainer
    DataInset(p::Point, q::Point, plot) = new(BoundingBox(p, q), plot)
    DataInset(p::Tuple, q::Tuple, plot) = DataInset(Point(p...), Point(q...), plot)
end

function boundingbox(self::DataInset, context::PlotContext)
    p = project(context.geom, lowerleft(self.plot_limits))
    q = project(context.geom, upperright(self.plot_limits))
    return BoundingBox(p, q)
end

function limits(self::DataInset, window::BoundingBox)
    return self.plot_limits
end

type PlotInset <: _Inset
    plot_limits::BoundingBox
    plot::PlotContainer
    PlotInset(p::Point, q::Point, plot) = new(BoundingBox(p, q), plot)
    PlotInset(p::Tuple, q::Tuple, plot) = PlotInset(Point(p...), Point(q...), plot)
end

function boundingbox(self::PlotInset, context::PlotContext)
    p = project(context.plot_geom, lowerleft(self.plot_limits))
    q = project(context.plot_geom, upperright(self.plot_limits))
    return BoundingBox(p, q)
end

function limits(self::PlotInset, window::BoundingBox)
    return BoundingBox()
end

# HalfAxis --------------------------------------------------------------------

function _magform(x)
    # Given x, returns (a,b), where x = a*10^b [a >= 1., b integral].
    if x == 0
        return 0., 0
    end
    a, b = modf(log10(abs(x)))
    a, b = 10^a, @compat Int(b)
    if a < 1.
        a, b = a * 10, b - 1
    end
    if x < 0.
        a = -a
    end
    return a, b
end

if VERSION < v"0.4-"
    const grisu = Base.Grisu.grisu
else
    grisu(a,b,c) = ((w,x,y,z) = Base.Grisu.grisu(a,b,c); (y,z[1:w],x))
end

function _format_ticklabel(x, range=0.; min_pow10=4)
    if x == 0
        return "0"
    end
    neg, digits, b = grisu(x, Base.Grisu.SHORTEST, @compat Int32(0))
    if length(digits) > 5
        neg, digits, b = grisu(x, Base.Grisu.PRECISION, @compat Int32(6))
        n = length(digits)
        while digits[n] == '0'
            n -= 1
        end
        digits = digits[1:n]
    end
    b -= 1
    if abs(b) >= min_pow10
        s = IOBuffer()
        if neg write(s, '-') end
        if digits != [0x31]
            write(s, @compat Char(digits[1]))
            if length(digits) > 1
                write(s, '.')
                for i = 2:length(digits)
                    write(s, @compat Char(digits[i]))
                end
            end
            write(s, "\\times ")
        end
        write(s, "10^{")
        write(s, dec(b))
        write(s, '}')
        return takebuf_string(s)
    end
    # XXX: @sprint doesn't implement %.*f
    #if range < 1e-6
    #    a, b = _magform(range)
    #    return @sprintf "%.*f" (abs(b),x)
    #end
    s = sprint(showcompact, x)
    endswith(s, ".0") ? s[1:end-2] : s
end

range(a::Real, b::Real) = (a <= b) ? (ceil(Int, a):floor(Int, b)) :
                                     (floor(Int, a):-1:ceil(Int, b))

function _ticklist_linear(lo, hi, sep, origin=0.)
    a = (lo - origin)/sep
    b = (hi - origin)/sep
    [ origin + i*sep for i in range(a,b) ]
end

function _ticks_default_linear(lim)
    a, b = _magform(abs(lim[2] - lim[1])/5.)
    if a < (1 + 2)/2.
        x = 1
    elseif a < (2 + 5)/2.
        x = 2
    elseif a < (5 + 10)/2.
        x = 5
    else
        x = 10
    end

    major_div = x * 10.0^b
    return _ticklist_linear(lim[1], lim[2], major_div)
end

function _ticks_default_log(lim)
    a = log10(lim[1])
    b = log10(lim[2])
    r = range(a, b)
    nn = length(r)

    if nn >= 10
        return 10.0 .^ _ticks_default_linear((a,b))
    elseif nn >= 2
        return 10.0 .^ r
    else
        return _ticks_default_linear(lim)
    end
end

_ticks_num_linear(lim, num) = linspace(lim[1], lim[2], num)
_ticks_num_log(lim, num) = logspace(log10(lim[1]), log10(lim[2]), num)

function _subticks_linear(lim, ticks, num=nothing)
    major_div = abs(ticks[end] - ticks[1])/float(length(ticks) - 1)
    if is(num,nothing)
        _num = 4
        a, b = _magform(major_div)
        if 1. < a < (2 + 5)/2.
            _num = 3
        end
    else
        _num = num
    end
    minor_div = major_div/float(_num+1)
    return _ticklist_linear(lim[1], lim[2], minor_div, ticks[1])
end

function _subticks_log(lim, ticks, num=nothing)
    a = log10(lim[1])
    b = log10(lim[2])
    r = range(a, b)
    nn = length(r)

    if nn >= 10
        return 10.0 .^ _subticks_linear((a,b), map(log10,ticks), num)
    elseif nn >= 2
        minor_ticks = Float64[]
        for i in (minimum(r)-1):maximum(r)
            for j in 1:9
                z = j * 10.0^i
                if (lim[1] <= z <= lim[2]) || (lim[1] >= z >= lim[2])
                    push!(minor_ticks, z)
                end
            end
        end
        return minor_ticks
    else
        return _subticks_linear(lim, ticks, num)
    end
end

abstract HalfAxis <: PlotComponent

type HalfAxisX <: HalfAxis
    attr::Dict
    func_ticks_default
    func_ticks_num
    func_subticks_default
    func_subticks_num

    function HalfAxisX(args...; kvs...)
        self = new(
            Dict(),
            (_ticks_default_linear, _ticks_default_log),
            (_ticks_num_linear, _ticks_num_log),
            (_subticks_linear, _subticks_log),
            (_subticks_linear, _subticks_log),
       )
        iniattr(self)
        kw_init(self, args...; kvs...)
        self
    end
end

_pos(self::HalfAxisX, context::PlotContext, a) = _pos(self, context, a, 0.)
function _pos(self::HalfAxisX, context::PlotContext, a, db)
    intcpt = _intercept(self, context)
    p = project(context.geom, a, intcpt)
    return Point(p[1], p[2] + db)
end

function _dpos(self::HalfAxisX, d)
    return Point(0., d)
end

function _align(self::HalfAxisX)
    if getattr(self, "ticklabels_dir") < 0
        return "center", "top"
    else
        return "center", "bottom"
    end
end

function _intercept(self::HalfAxisX, context)
    if !is(getattr(self,"intercept"),nothing)
        return getattr(self, "intercept")
    end
    limits = context.data_bbox
    if (getattr(self, "ticklabels_dir") < 0) $ context.yflipped
        return yrange(limits)[1]
    else
        return yrange(limits)[2]
    end
end

function _log(self::HalfAxisX, context)
    if is(getattr(self,"log"),nothing)
        return context.xlog
    end
    return getattr(self, "log")
end

function _side(self::HalfAxisX)
    if getattr(self, "ticklabels_dir") < 0
        return "bottom"
    else
        return "top"
    end
end

function _range(self::HalfAxisX, context)
    r = getattr(self, "range")
    if !is(r,nothing)
        a,b = r
        if is(a,nothing) || is(b,nothing)
            c,d = xrange(context.data_bbox)
            if is(a,nothing)
                a = c
            end
            if is(b,nothing)
                b = d
            end
            return a,b
        else
            return r
        end
    end
    return xrange(context.data_bbox)
end

function _make_grid(self::HalfAxisX, context, ticks)
    objs = GroupPainter(getattr(self,:grid_style))
    if isequal(ticks,nothing)
        return objs
    end
    for tick in ticks
        l = LineX(tick)
        push!(objs, make(l,context))
    end
    objs
end

type HalfAxisY <: HalfAxis
    attr::Dict
    func_ticks_default
    func_ticks_num
    func_subticks_default
    func_subticks_num

    function HalfAxisY(args...; kvs...)
        self = new(
            Dict(),
            (_ticks_default_linear, _ticks_default_log),
            (_ticks_num_linear, _ticks_num_log),
            (_subticks_linear, _subticks_log),
            (_subticks_linear, _subticks_log),
       )
        iniattr(self)
        kw_init(self, args...; kvs...)
        self
    end
end

_pos(self::HalfAxisY, context, a) = _pos(self, context, a, 0.)
function _pos(self::HalfAxisY, context, a, db)
    p = project(context.geom, _intercept(self, context), a)
    return Point(p[1] + db, p[2])
end

function _dpos(self::HalfAxisY, d)
    return Point(d, 0.)
end

function _align(self::HalfAxisY)
    if getattr(self, "ticklabels_dir") > 0
        return "left", "center"
    else
        return "right", "center"
    end
end

function _intercept(self::HalfAxisY, context)
    intercept = getattr(self, "intercept")
    if !is(intercept,nothing)
        return intercept
    end
    limits = context.data_bbox
    if (getattr(self, "ticklabels_dir") > 0) $ context.xflipped
        return xrange(limits)[2]
    else
        return xrange(limits)[1]
    end
end

function _log(self::HalfAxisY, context)
    if is(getattr(self,"log"),nothing)
        return context.ylog
    end
    return getattr(self, "log")
end

function _side(self::HalfAxisY)
    if getattr(self, "ticklabels_dir") > 0
        return "right"
    else
        return "left"
    end
end

function _range(self::HalfAxisY, context)
    r = getattr(self, "range")
    if !is(r,nothing)
        a,b = r
        if is(a,nothing) || is(b,nothing)
            c,d = yrange(context.data_bbox)
            if is(a,nothing)
                a = c
            end
            if is(b,nothing)
                b = d
            end
            return a,b
        else
            return r
        end
    end
    return yrange(context.data_bbox)
end

function _make_grid(self::HalfAxisY, context, ticks)
    objs = GroupPainter(getattr(self,:grid_style))
    if isequal(ticks,nothing)
        return objs
    end
    for tick in ticks
        l = LineY(tick)
        push!(objs, make(l,context))
    end
    objs
end

# defaults

_attr_map(::HalfAxis) = @Dict(
    :labeloffset       => :label_offset,
    :major_ticklabels  => :ticklabels,
    :major_ticks       => :ticks,
    :minor_ticks       => :subticks,
)

function _ticks(self::HalfAxis, context)
    logidx = _log(self, context) ? 2 : 1
    r = _range(self, context)
    ticks = getattr(self, "ticks")
    if isequal(ticks,nothing)
        return self.func_ticks_default[logidx](r)
    elseif typeof(ticks) <: Integer
        return self.func_ticks_num[logidx](r, ticks)
    else
        return ticks
    end
end

function _subticks(self::HalfAxis, context, ticks)
    logidx = _log(self, context) ? 2 : 1
    r = _range(self, context)
    subticks = getattr(self, "subticks")
    if isequal(subticks,nothing)
        return self.func_subticks_default[logidx](r, ticks)
    elseif typeof(subticks) <: Integer
        return self.func_subticks_num[logidx](r, ticks, subticks)
    else
        return subticks
    end
end

function _ticklabels(self::HalfAxis, context, ticks)
    ticklabels = getattr(self, "ticklabels")
    if !isequal(ticklabels,nothing)
        return ticklabels
    end
    r = maximum(ticks) - minimum(ticks)
    [ _format_ticklabel(x,r) for x=ticks ]
end

function _make_ticklabels(self::HalfAxis, context, pos, labels)
    if isequal(labels,nothing) || length(labels) <= 0
        return GroupPainter()
    end

    dir = getattr(self, "ticklabels_dir")
    offset = _size_relative(getattr(self, "ticklabels_offset"),
        context.dev_bbox)
    draw_ticks = getattr(self, "draw_ticks")
    if draw_ticks && getattr(self, "tickdir") > 0
        offset = offset + _size_relative(
            getattr(self, "ticks_size"), context.dev_bbox)
    end

    labelpos = Point[ _pos(self, context, pos[i], dir*offset) for i=1:length(labels) ]

    halign, valign = _align(self)

    style = Dict{Symbol,Any}()
    style[:texthalign] = halign
    style[:textvalign] = valign
    for (k,v) in getattr(self, :ticklabels_style)
        style[k] = v
    end

    l = LabelsPainter(labelpos, labels; halign=style[:texthalign], valign=style[:textvalign])
    GroupPainter(style, l)
end

function _make_spine(self::HalfAxis, context)
    a, b = _range(self, context)
    p = _pos(self, context, a)
    q = _pos(self, context, b)
    GroupPainter(getattr(self,:spine_style), LinePainter(p,q))
end

function _make_strut(self::HalfAxis, context)
    a, b = _range(self, context)
    p = _pos(self, context, a)
    q = _pos(self, context, b)
    StrutPainter(BoundingBox(p,q))
end

function _make_ticks(self::HalfAxis, context, ticks, size, style)
    if isequal(ticks,nothing) || length(ticks) <= 0
        return GroupPainter()
    end

    dir = getattr(self, "tickdir") * getattr(self, "ticklabels_dir")
    ticklen = _dpos(self, dir * _size_relative(size, context.dev_bbox))

    tickpos = Point[ _pos(self, context, tick) for tick in ticks ]

    GroupPainter(style, CombPainter(tickpos, ticklen))
end

function make(self::HalfAxis, context)
    objs = GroupPainter(getattr(self,:style))
    if getattr(self, "draw_nothing")
        return objs
    end

    ticks = _ticks(self, context)
    subticks = _subticks(self, context, ticks)
    ticklabels = _ticklabels(self, context, ticks)
    draw_ticks = getattr(self, "draw_ticks")
    draw_subticks = getattr(self, "draw_subticks")
    draw_ticklabels = getattr(self, "draw_ticklabels")

    implicit_draw_subticks = is(draw_subticks,nothing) && draw_ticks

    implicit_draw_ticklabels = is(draw_ticklabels,nothing) &&
        (!is(getattr(self, "range"),nothing) || !is(getattr(self, "ticklabels"),nothing))

    if getattr(self, "draw_grid")
        push!(objs, _make_grid(self, context, ticks))
    end

    if getattr(self, "draw_axis")
        if (!is(draw_subticks,nothing) && draw_subticks) || implicit_draw_subticks
            push!(objs, _make_ticks(self, context, subticks,
                getattr(self, "subticks_size"),
                getattr(self, "subticks_style")))
        end

        if draw_ticks
            push!(objs, _make_ticks(self, context, ticks,
                getattr(self, "ticks_size"),
                getattr(self, "ticks_style")))
        end

        if getattr(self, "draw_spine")
            push!(objs, _make_spine(self, context))
        end
    end

    if (!is(draw_ticklabels,nothing) && draw_ticklabels) || implicit_draw_ticklabels
        push!(objs, _make_ticklabels(self, context, ticks, ticklabels))
    end

    # has to be made last
    if hasattr(self, "label")
        if !is(getattr(self, "label"),nothing) # XXX:remove
            isempty(objs) && push!(objs, _make_strut(self, context))
            bl = BoxLabel(
                objs,
                getattr(self, "label"),
                _side(self),
                getattr(self, "label_offset"),
                getattr(self, "label_style"))
            push!(objs, make(bl,context))
        end
    end
    objs
end

# PlotComposite ---------------------------------------------------------------

type PlotComposite <: HasStyle
    attr::Dict
    components::Vector{Any}
    dont_clip::Bool

    function PlotComposite(args...; kvs...)
        self = new(Dict(), Any[], false)
        kw_init(self, args...; kvs...)
        self
    end
end

function add(self::PlotComposite, args::PlotComponent...)
    for arg in args
        push!(self.components, arg)
    end
    self
end

function clear(self::PlotComposite)
    self.components = Any[]
end

function isempty(self::PlotComposite)
    return isempty(self.components)
end

function limits(self::PlotComposite, window::BoundingBox)
    bb = BoundingBox()
    for obj in self.components
        bb += limits(obj, window)
    end
    return bb
end

function make(self::PlotComposite, context)
end

function boundingbox(self::PlotComposite, context)
    make(self, context)
    bb = BoundingBox()
    for obj in self.components
        bb += boundingbox(obj,context)
    end
    return bb
end

function render(self::PlotComposite, context)
    make(self, context)
    push_style(context.paintc, getattr(self,"style"))
    if !self.dont_clip
        set(context.draw, "cliprect", context.dev_bbox)
    end
    for obj in self.components
        render(obj, context)
    end
    pop_style(context.paintc)
end

# FramedPlot ------------------------------------------------------------------

type _Alias <: HasAttr
    objs
    _Alias(args...) = new(args)
end

function setattr(self::_Alias, name::Symbol, value)
    for obj in self.objs
        setattr(obj, name, value)
    end
end

type FramedPlot <: PlotContainer
    attr::Associative # TODO: does Associative need {K,V}?
    content1::PlotComposite
    content2::PlotComposite
    x1::HalfAxis
    y1::HalfAxis
    x2::HalfAxis
    y2::HalfAxis
    frame::_Alias
    frame1::_Alias
    frame2::_Alias
    x::_Alias
    y::_Alias

    function FramedPlot(args...; kvs...)
        x1 = HalfAxisX()
        setattr(x1, :ticklabels_dir, -1)
        y1 = HalfAxisY()
        setattr(y1, :ticklabels_dir, -1)
        x2 = HalfAxisX()
        setattr(x2, :draw_ticklabels, nothing)
        y2 = HalfAxisY()
        setattr(y2, :draw_ticklabels, nothing)
        self = new(
            Dict(),
            PlotComposite(),
            PlotComposite(),
            x1, y1, x2, y2,
            _Alias(x1, x2, y1, y2),
            _Alias(x1, y1),
            _Alias(x2, y2),
            _Alias(x1, x2),
            _Alias(y1, y2),
        )
        gs = Dict{Symbol,Any}()
        gs[:linekind] = "dot"
        setattr(self.frame, :grid_style, gs)
        setattr(self.frame, :tickdir, -1)
        setattr(self.frame1, :draw_grid, false)
        iniattr(self, args...; kvs...)
        self
    end
end

_attr_map(fp::FramedPlot) = @Dict(
    :xlabel    => (fp.x1, :label),
    :ylabel    => (fp.y1, :label),
    :xlog      => (fp.x1, :log),
    :ylog      => (fp.y1, :log),
    :xrange    => (fp.x1, :range),
    :yrange    => (fp.y1, :range),
    :xtitle    => (fp.x1, :label),
    :ytitle    => (fp.y1, :label),
)

function getattr(self::FramedPlot, name::Symbol)
    am = _attr_map(self)
    if haskey(am, name)
        a,b = am[name]
        return getattr(a, b)
    else
        return self.attr[name]
    end
end

function setattr(self::FramedPlot, name::Symbol, value)
    am = _attr_map(self)
    if haskey(am, name)
        a,b = am[name]
        setattr(a, b, value)
    else
        self.attr[name] = value
    end
end

function isempty(self::FramedPlot)
    return isempty(self.content1) && isempty(self.content2)
end

function add(self::FramedPlot, args::PlotComponent...)
    add(self.content1, args...)
    self
end

function add2(self::FramedPlot, args::PlotComponent...)
    add(self.content2, args...)
    self
end

myprevfloat(x::Float64) = x - eps(x)
mynextfloat(x::Float64) = x + eps(x)

function user_range(range)
    lo = NaN
    hi = NaN
    flipped = false
    if range !== nothing
        b1 = typeof(range[1]) <: Real
        b2 = typeof(range[2]) <: Real
        if b1 && b2
            x1 = @compat Float64(range[1])
            x2 = @compat Float64(range[2])
            lo = myprevfloat(min(x1, x2))
            hi = mynextfloat(max(x1, x2))
            flipped = x1 > x2
        else
            b1 && (lo = myprevfloat(@compat Float64(range[1])))
            b2 && (hi = mynextfloat(@compat Float64(range[2])))
        end
    end
    lo, hi, flipped
end

function bbox_to_rect(bbox::BoundingBox, xflipped::Bool, yflipped::Bool)
    a = xflipped ? (bbox.xmax,bbox.xmin) : (bbox.xmin,bbox.xmax)
    b = yflipped ? (bbox.ymax,bbox.ymin) : (bbox.ymin,bbox.ymax)
    Rectangle(a..., b...)
end

function margin_expand(margin::Real, a::Real, b::Real, islog::Bool)
    if islog
        f = a == b ? 1.1 : 10.0^(0.5*margin*(log10(b) - log10(a)))
        return a/f, b*f
    else
        d = a == b ? 1. : 0.5*margin*(b - a)
        return a-d, b+d
    end
end

function override(bb1::BoundingBox, bb2::BoundingBox)
    BoundingBox(
        isnan(bb1.xmin) ? bb2.xmin : bb1.xmin,
        isnan(bb1.xmax) ? bb2.xmax : bb1.xmax,
        isnan(bb1.ymin) ? bb2.ymin : bb1.ymin,
        isnan(bb1.ymax) ? bb2.ymax : bb1.ymax)
end

function limits(margin, xrange, yrange, xlog, ylog, content)
    xmin,xmax,xflipped = user_range(xrange)
    ymin,ymax,yflipped = user_range(yrange)
    user_bbox = BoundingBox(xmin, xmax, ymin, ymax)
    geom_bbox = BoundingBox(xlog ? 0. : -Inf, Inf, ylog ? 0. : -Inf, Inf)

    # check that user values are valid
    user_bbox.xmin <= geom_bbox.xmin && throw(WinstonException("bad xmin"))
    user_bbox.xmax >= geom_bbox.xmax && throw(WinstonException("bad xmax"))
    user_bbox.ymin <= geom_bbox.ymin && throw(WinstonException("bad ymin"))
    user_bbox.ymax >= geom_bbox.ymax && throw(WinstonException("bad ymax"))

    if !isincomplete(user_bbox)
        return bbox_to_rect(user_bbox, xflipped, yflipped)
    end

    data_bbox = limits(content, geom_bbox & user_bbox)
    isincomplete(data_bbox) && throw(WinstonException("no data in range"))

    a,b = margin_expand(margin, data_bbox.xmin, data_bbox.xmax, xlog)
    c,d = margin_expand(margin, data_bbox.ymin, data_bbox.ymax, ylog)
    computed_bbox = BoundingBox(a, b, c, d)

    # user trumps computed
    bbox = override(user_bbox, computed_bbox)

    bbox_to_rect(bbox, xflipped, yflipped)
end

function limits(fp::FramedPlot)
    margin = getattr(fp,    :gutter)
    xrange = getattr(fp.x1, :range)
    yrange = getattr(fp.y1, :range)
    xlog   = getattr(fp.x1, :log)
    ylog   = getattr(fp.y1, :log)
    limits(margin, xrange, yrange, xlog, ylog, fp.content1)
end

function limits2(fp::FramedPlot)
    xrange = getattr(fp.x2, :range)
    yrange = getattr(fp.y2, :range)

    if !isempty(fp.content2)
        margin = getattr(fp,    :gutter)
        xlog   = getattr(fp.x2, :log)
        ylog   = getattr(fp.y2, :log)

        xlog === nothing && (xlog = getattr(fp.x1, :log))
        ylog === nothing && (ylog = getattr(fp.y1, :log))

        return limits(margin, xrange, yrange, xlog, ylog, fp.content2)
    end

    xrange === nothing && (xrange = getattr(fp.x1,:range))
    yrange === nothing && (yrange = getattr(fp.y1,:range))

    rect = limits(fp)
    computed_bbox = BoundingBox(rect)

    xmin,xmax,xflipped = user_range(xrange)
    ymin,ymax,yflipped = user_range(yrange)
    user_bbox = BoundingBox(xmin, xmax, ymin, ymax)

    bbox = override(user_bbox, computed_bbox)
    Rectangle(bbox, xflipped, yflipped)
end

function _context1(self::FramedPlot, device::Renderer, region::BoundingBox)
    xlog = getattr(self.x1, :log)
    ylog = getattr(self.y1, :log)
    lims = limits(self)
    proj = PlotGeometry(lims, region, xlog, ylog)
    return PlotContext(device, region, lims, proj, xlog, ylog)
end

function _context2(self::FramedPlot, device::Renderer, region::BoundingBox)
    xlog = getattr(self.x1, :log)
    ylog = getattr(self.y1, :log)

    getattr(self.x2, :log) !== nothing && (xlog = getattr(self.x2, :log))
    getattr(self.y2, :log) !== nothing && (ylog = getattr(self.y2, :log))

    lims = limits2(self)
    proj = PlotGeometry(lims, region, xlog, ylog)
    return PlotContext(device, region, lims, proj, xlog, ylog)
end

function exterior(self::FramedPlot, device::Renderer, region::BoundingBox)
    bb = region

    context1 = _context1(self, device, region)
    bb += boundingbox(self.x1, context1) +
          boundingbox(self.y1, context1)

    context2 = _context2(self, device, region)
    bb += boundingbox(self.x2, context2) +
          boundingbox(self.y2, context2)

    return bb
end

function compose_interior(self::FramedPlot, device::Renderer, region::BoundingBox)
    invoke(compose_interior, (PlotContainer,Renderer,BoundingBox), self, device, region)

    context1 = _context1(self, device, region)
    context2 = _context2(self, device, region)

    render(self.content1, context1)
    render(self.content2, context2)

    render(self.y2, context2)
    render(self.x2, context2)
    render(self.y1, context1)
    render(self.x1, context1)
end

getcomponents(p::FramedPlot, c) = p.([:content1, :content2][c]).components
getcomponents(p::FramedPlot) = [getcomponents(p,1); getcomponents(p,2)]

rmcomponents(p::FramedPlot, i::Integer, c) = splice!(p.([:content1, :content2][c]).components, i)

function rmcomponents(p::FramedPlot, i::Integer)
    cont1 = getcomponents(p, 1)
    cont2 = getcomponents(p, 2)
    if i <= length(cont1)
        rmcomponents(p, i, 1)
    elseif i <= length(cont1) + length(cont2)
        rmcomponents(p, i - lenght(cont1), 2)
    else
        error("Requested remove item #$i from $(length(cont1)+length(cont2)) components.")
    end
end

function rmcomponents(p::FramedPlot, v::AbstractVector, args...)
    eltype(v) <: Integer && sort!(v, rev=true)
    for i in v
        rmcomponents(p, i, args...)
    end
end

function rmcomponents(p::FramedPlot, t::Type, args...)
    ctypes = map(typeof, getcomponents(p, args...))
    todel = find(map(x -> (x <: t), ctypes))
    rmcomponents(p, todel, args...)
end
    
# Table ------------------------------------------------------------------------

type _Grid
    nrows::Int
    ncols::Int
    origin
    step_x
    step_y
    cell_dimen

    function _Grid(nrows, ncols, bbox, cellpadding, cellspacing)
        self = new()
        self.nrows = nrows
        self.ncols = ncols

        w, h = width(bbox), height(bbox)
        cp = _size_relative(cellpadding, bbox)
        cs = _size_relative(cellspacing, bbox)

        self.origin = lowerleft(bbox) + Point(cp,cp)
        self.step_x = (w + cs)/ncols
        self.step_y = (h + cs)/nrows
        self.cell_dimen = (self.step_x - cs - 2*cp,
            self.step_y - cs - 2*cp)
        self
    end
end

function cellbb(self::_Grid, i::Int, j::Int)
    ii = self.nrows - i
    p = self.origin + Point((j-1)*self.step_x, ii*self.step_y)
    return BoundingBox(p.x, p.x+self.cell_dimen[1], p.y, p.y + self.cell_dimen[2])
end

type Table <: PlotContainer
    attr::PlotAttributes
    rows::Int
    cols::Int
    content

    function Table(rows, cols, args...)
        self = new(Dict())
        iniattr(self, args...)
        self.rows = rows
        self.cols = cols
        self.content = cell(rows, cols)
        self
    end
end

function getindex(self::Table, row::Int, col::Int)
    return self.content[row,col]
end

function setindex!(self::Table, obj::PlotContainer, row::Int, col::Int)
    self.content[row,col] = obj
end

function isempty(self::Table)
    for i = 1:self.rows
        for j = 1:self.cols
            isdefined(self.content, i, j) && return false
        end
    end
    true
end

function exterior(self::Table, device::Renderer, intbbox::BoundingBox)
    ext = intbbox

    if getattr(self, "align_interiors")
        g = _Grid(self.rows, self.cols, intbbox,
            getattr(self,"cellpadding"), getattr(self,"cellspacing"))

        for i = 1:self.rows
            for j = 1:self.cols
                if isdefined(self.content, i, j)
                    obj = self.content[i,j]
                    subregion = cellbb(g, i, j)
                    ext += exterior(obj, device, subregion)
                end
            end
        end
    end
    return ext
end

function compose_interior(self::Table, device::Renderer, intbbox::BoundingBox)
    invoke(compose_interior, (PlotContainer,Renderer,BoundingBox), self, device, intbbox)

    g = _Grid(self.rows, self.cols, intbbox,
        getattr(self,"cellpadding"), getattr(self,"cellspacing"))

    for i = 1:self.rows
        for j = 1:self.cols
            if isdefined(self.content, i, j)
                obj = self.content[i,j]
                subregion = cellbb(g, i, j)
                if getattr(self, "align_interiors")
                    compose_interior(obj, device, subregion)
                else
                    compose(obj, device, subregion)
                end
            end
        end
    end
end

# Plot ------------------------------------------------------------------------

type Plot <: PlotContainer
    attr::PlotAttributes
    content

    function Plot(args...)
        self = new(Dict())
        iniattr(self, args...)
        self.content = PlotComposite()
        self
    end
end

function isempty(self::Plot)
    return isempty(self.content)
end

function add(self::Plot, args::PlotComponent...)
    add(self.content, args...)
    self
end

function limits(self::Plot, window::BoundingBox)
    return _limits(limits(self.content,window), getattr(self,"gutter"),
                   getattr(self,"xlog"), getattr(self,"ylog"),
                   getattr(self,"xrange"), getattr(self,"yrange"))
end

compose_interior(self::Plot, device::Renderer, region::BoundingBox) =
    compose_interior(self, device, region, nothing)
function compose_interior(self::Plot, device, region, lmts)
    if is(lmts,nothing)
        lmts = limits(self)
    end
    xlog = getattr(self,"xlog")
    ylog = getattr(self,"ylog")
    proj = PlotGeometry(lmts, region, xlog, ylog)
    context = PlotContext(device, region, lmts, proj, xlog, ylog)
    render(self.content, context)
end

compose(self::Plot, device::Renderer, region::BoundingBox) =
    compose(self, device, region, nothing)
function compose(self::Plot, device, region, lmts)
    int_bbox = interior(self, device, region)
    compose_interior(self, device, int_bbox, lmts)
end

# FramedArray -----------------------------------------------------------------
#
# Quick and dirty, dirty hack...
#

function _frame_draw(obj, device, region, limits, labelticks)
    frame = Frame(labelticks)
    xlog = getattr(obj, "xlog")
    ylog = getattr(obj, "ylog")
    proj = PlotGeometry(limits, region, xlog, ylog)
    context = PlotContext(device, region, limits, proj, xlog, ylog)
    render(frame, context)
end

_frame_bbox(obj, device, region, limits) =
    _frame_bbox(obj, device, region, limits, (0,1,1,0))
function _frame_bbox(obj, device, region, limits, labelticks)
    frame = Frame(labelticks)
    xlog = getattr(obj, "xlog")
    ylog = getattr(obj, "ylog")
    proj = PlotGeometry(limits, region, xlog, ylog)
    context = PlotContext(device, region, limits, proj, xlog, ylog)
    return boundingbox(frame, context)
end

function _range_union(a, b)
    if is(a,nothing)
        return b
    end
    if is(b,nothing)
        return a
    end
    return min(a[1],b[1]), max(a[2],b[2])
end

type FramedArray <: PlotContainer
    attr::PlotAttributes
    nrows::Int
    ncols::Int
    content::Array{Any,2}

    function FramedArray(nrows, ncols, args...; kvs...)
        self = new(Dict())
        self.nrows = nrows
        self.ncols = ncols
        self.content = cell(nrows, ncols)
        for i in 1:nrows
            for j in 1:ncols
                self.content[i,j] = Plot()
            end
        end
        iniattr(self, args...; kvs...)
        self
    end
end

function getindex(self::FramedArray, row::Int, col::Int)
    return self.content[row,col]
end

# XXX:fixme
isempty(self::FramedArray) = false

function setattr(self::FramedArray, name::Symbol, value)
    _attr_distribute = Set(
        "gutter",
        "xlog",
        "ylog",
        "xrange",
        "yrange",
    )
    if name in _attr_distribute
        for i in 1:self.nrows, j=1:self.ncols
            setattr(self.content[i,j], name, value)
        end
    else
        self.attr[name] = value
    end
end

function _limits(self::FramedArray, i, j)
    if getattr(self, "uniform_limits")
        return _limits_uniform(self)
    else
        return _limits_nonuniform(self, i, j)
    end
end

function _limits_uniform(self::FramedArray)
    lmts = BoundingBox()
    for i in 1:self.nrows, j=1:self.ncols
        obj = self.content[i,j]
        # XXX:fixme
        window = BoundingBox(-Inf, Inf, -Inf, Inf)
        lmts += limits(obj, window)
    end
    return lmts
end

function _limits_nonuniform(self::FramedArray, i, j)
    lx = nothing
    for k in 1:self.nrows
        # XXX:fixme
        window = BoundingBox(-Inf, Inf, -Inf, Inf)
        l = limits(self.content[k,j], window)
        lx = _range_union(xrange(l), lx)
    end
    ly = nothing
    for k in 1:self.ncols
        # XXX:fixme
        window = BoundingBox(-Inf, Inf, -Inf, Inf)
        l = limits(self.content[i,k], window)
        ly = _range_union(yrange(l), ly)
    end
    return BoundingBox(lx[1], lx[2], ly[1], ly[2])
end

function _grid(self::FramedArray, interior)
    return _Grid(self.nrows, self.ncols, interior, 0., getattr(self, "cellspacing"))
end

function _frames_bbox(self::FramedArray, device, interior)
    bb = BoundingBox()
    g = _grid(self, interior)
    corners = [(1,1),(self.nrows,self.ncols)]

    for (i,j) in corners
        obj = self.content[i,j]
        subregion = cellbb(g, i, j)
        limits = _limits(self, i, j)
        axislabels = [0,0,0,0]
        if i == self.nrows
            axislabels[2] = 1
        end
        if j == 1
            axislabels[3] = 1
        end
        bb += _frame_bbox(obj, device, subregion, limits, axislabels)
    end

    return bb
end

function exterior(self::FramedArray, device::Renderer, int_bbox::BoundingBox)
    bb = _frames_bbox(self, device, int_bbox)

    labeloffset = _size_relative(getattr(self,"label_offset"), int_bbox)
    labelsize = _fontsize_relative(
        getattr(self,"label_size"), int_bbox, boundingbox(device))
    margin = labeloffset + labelsize

    if !is(getattr(self,"xlabel"),nothing)
        bb = deform(bb, 0, 0, margin, 0)
    end
    if !is(getattr(self,"ylabel"),nothing)
        bb = deform(bb, margin, 0, 0, 0)
    end

    return bb
end

function _frames_draw(self::FramedArray, device, interior)
    g = _grid(self, interior)

    for i in 1:self.nrows, j=1:self.ncols
        obj = self.content[i,j]
        subregion = cellbb(g, i, j)
        limits = _limits(self, i, j)
        axislabels = [0,0,0,0]
        if i == self.nrows
            axislabels[2] = 1
        end
        if j == 1
            axislabels[3] = 1
        end
        _frame_draw(obj, device, subregion, limits, axislabels)
    end
end

function _data_draw(self::FramedArray, device, interior)
    g = _grid(self, interior)

    for i in 1:self.nrows, j=1:self.ncols
        obj = self.content[i,j]
        subregion = cellbb(g, i, j)
        lmts = _limits(self, i, j)
        compose_interior(obj, device, subregion, lmts)
    end
end

function _labels_draw(self::FramedArray, device::Renderer, int_bbox::BoundingBox)
    bb = _frames_bbox(self, device, int_bbox)

    labeloffset = _size_relative(getattr(self,"label_offset"), int_bbox)
    labelsize = _fontsize_relative(
        getattr(self,"label_size"), int_bbox, boundingbox(device))

    save_state(device)
    set(device, "fontsize", labelsize)
    if !is(getattr(self,"xlabel"),nothing)
        x = center(int_bbox).x
        y = ymin(bb) - labeloffset
        textdraw(device, x, y, getattr(self,"xlabel"); halign="center", valign="top")
    end
    if !is(getattr(self,"ylabel"),nothing)
        x = xmin(bb) - labeloffset
        y = center(int_bbox).y
        textdraw(device, x, y, getattr(self,"ylabel"); angle=90., halign="center", valign="bottom")
    end
    restore_state(device)
end

function add(self::FramedArray, args::PlotComponent...)
    for i in 1:self.nrows, j=1:self.ncols
        obj = self.content[i,j]
        add(obj, args...)
    end
    self
end

function compose_interior(self::FramedArray, device::Renderer, int_bbox::BoundingBox)
    invoke(compose_interior, (PlotContainer,Renderer,BoundingBox), self, device, int_bbox)
    _data_draw(self, device, int_bbox)
    _frames_draw(self, device, int_bbox)
    _labels_draw(self, device, int_bbox)
end

# Frame -----------------------------------------------------------------------

#type Frame
#    pc::PlotComposite
#    x1
#    x2
#    y1
#    y2
#
#    #function __init__(self, labelticks=(0,1,1,0), args...)
#        #apply(_PlotComposite.__init__, (self,), args...)
#    function Frame(labelticks, args...)
#        self = new()
#        pc = PlotComposite(args...)
#        pc.dont_clip = 1
#
#        self.x2 = _HalfAxisX()
#        self.x2.draw_ticklabels = labelticks[1]
#        self.x2.ticklabels_dir = 1
#
#        self.x1 = _HalfAxisX()
#        self.x1.draw_ticklabels = labelticks[2]
#        self.x1.ticklabels_dir = -1
#
#        self.y1 = _HalfAxisY()
#        self.y1.draw_ticklabels = labelticks[3]
#        self.y1.ticklabels_dir = -1
#
#        self.y2 = _HalfAxisY()
#        self.y2.draw_ticklabels = labelticks[4]
#        self.y2.ticklabels_dir = 1
#        self
#    end
#end
#
#function make(self::Frame, context)
#    clear(self)
#    add(self, self.x1, self.x2, self.y1, self.y2)
#end

function Frame(labelticks, args...)
    #apply(_PlotComposite.__init__, (self,), args...)
    pc = PlotComposite(args...)
    setattr(pc, "dont_clip", true)

    x2 = HalfAxisX()
    setattr(x2, "draw_ticklabels", labelticks[1]==1)
    setattr(x2, "ticklabels_dir", 1)

    x1 = HalfAxisX()
    setattr(x1, "draw_ticklabels", labelticks[2]==1)
    setattr(x1, "ticklabels_dir", -1)

    y1 = HalfAxisY()
    setattr(y1, "draw_ticklabels", labelticks[3]==1)
    setattr(y1, "ticklabels_dir", -1)

    y2 = HalfAxisY()
    setattr(y2, "draw_ticklabels", labelticks[4]==1)
    setattr(y2, "ticklabels_dir", 1)

    add(pc, x1, x2, y1, y2)
    pc
end

# PlotContainer ---------------------------------------------------------------

function show(io::IO, self::PlotContainer)
    print(io, typeof(self), "(...)")
end

function interior(self::PlotContainer, device::Renderer, exterior_bbox::BoundingBox)
    TOL = 0.005

    interior_bbox = exterior_bbox
    region_diagonal = diagonal(exterior_bbox)

    for i in 1:10
        bb = exterior(self, device, interior_bbox)

        dll = lowerleft(exterior_bbox) - lowerleft(bb)
        dur = upperright(exterior_bbox) - upperright(bb)

        sll = norm(dll) / region_diagonal
        sur = norm(dur) / region_diagonal

        if sll < TOL && sur < TOL
            # XXX:fixme
            ar = getattr(self, "aspect_ratio")
            if !is(ar,nothing)
                interior_bbox = with_aspect_ratio(interior_bbox, ar)
            end
            return interior_bbox
        end

        scale = diagonal(interior_bbox) / diagonal(bb)
        dll = scale * dll
        dur = scale * dur

        interior_bbox = BoundingBox(lowerleft(interior_bbox) + dll,
                                    upperright(interior_bbox) + dur)
    end

    println("warning: sub-optimal solution for plot")
    return interior_bbox
end

function exterior(self::PlotContainer, device::Renderer, interior::BoundingBox)
    return interior
end

function compose_interior(self::PlotContainer, device::Renderer, int_bbox::BoundingBox)
    # XXX: separate out into its own component
    if hasattr(self, :title)
        offset = _size_relative(getattr(self, :title_offset), int_bbox)
        ext_bbox = exterior(self, device, int_bbox)
        x = center(int_bbox).x
        y = ymax(ext_bbox) + offset
        style = Dict()
        for (k,v) in getattr(self, :title_style)
            style[k] = v
        end
        style[:fontsize] = _fontsize_relative(
            getattr(self,:title_style)[:fontsize], int_bbox, boundingbox(device))
        save_state(device)
        for (key,val) in style
            set(device, key, val)
        end
        textdraw(device, x, y, getattr(self,:title); halign="center", valign="bottom")
        restore_state(device)
    end
end

function compose(self::PlotContainer, device::Renderer, region::BoundingBox)
    if isempty(self) return end
    ext_bbox = region
    if hasattr(self, :title)
        offset = _size_relative(getattr(self,"title_offset"), ext_bbox)
        fontsize = _fontsize_relative(
            getattr(self,:title_style)[:fontsize], ext_bbox, boundingbox(device))
        ext_bbox = deform(ext_bbox, 0, 0, 0, -offset-fontsize)
    end
    int_bbox = interior(self, device, ext_bbox)
    compose_interior(self, device, int_bbox)
end

page_compose(self::PlotContainer, device::GraphicsDevice) =
    page_compose(self, CairoRenderer(device))

function page_compose(self::PlotContainer, device::Renderer)
    bb = boundingbox(device)
    for (key,val) in config_options("defaults")
        set(device, key, val)
    end
    bb *= 1.0 - getattr(self, :page_margin)
    save(device.ctx)
    Cairo.scale(device.ctx,1.0,-1.0)
    Cairo.translate(device.ctx,0.0,-height(device))
    compose(self, device, bb)
    restore(device.ctx)
end

function write_to_surface(p::PlotContainer, surface)
    r = CairoRenderer(surface)
    page_compose(p, r)
    show_page(r.ctx)
    finish(surface)
end

function savesvg(p::PlotContainer, io::IO, width, height)
    surface = CairoSVGSurface(io, width, height)
    write_to_surface(p, surface)
end

function savesvg(p::PlotContainer, filename::AbstractString, width, height)
    io = Base.FS.open(filename, Base.JL_O_CREAT|Base.JL_O_TRUNC|Base.JL_O_WRONLY, 0o644)
    savesvg(p, io, width, height)
    close(io)
    nothing
end

function saveeps(self::PlotContainer, filename::AbstractString, width::AbstractString, height::AbstractString)
    saveeps(self, filename, _str_size_to_pts(width), _str_size_to_pts(height))
end

function saveeps(self::PlotContainer, filename::AbstractString, width::Real, height::Real)
    surface = CairoEPSSurface(filename, width, height)
    write_to_surface(self, surface)
end

function savepdf(self, filename::AbstractString, width::AbstractString, height::AbstractString)
    savepdf(self, filename, _str_size_to_pts(width), _str_size_to_pts(height))
end

function savepdf(self::PlotContainer, filename::AbstractString, width::Real, height::Real)
    surface = CairoPDFSurface(filename, width, height)
    write_to_surface(self, surface)
end

function savepdf{T<:PlotContainer}(plots::Vector{T}, filename::AbstractString, width::Real, height::Real)
    surface = CairoPDFSurface(filename, width, height)
    r = CairoRenderer(surface)
    for plt in plots
        page_compose(plt, r)
        show_page(r.ctx)
    end
    finish(surface)
end

function savepng(self::PlotContainer, io_or_filename::(@compat Union{IO,AbstractString}), width::Int, height::Int)
    surface = CairoRGBSurface(width, height)
    r = CairoRenderer(surface)
    set_source_rgb(r.ctx, 1.,1.,1.)
    paint(r.ctx)
    set_source_rgb(r.ctx, 0.,0.,0.)
    page_compose(self, r)
    write_to_png(surface, io_or_filename)
    finish(surface)
end

function savefig(self::PlotContainer, filename::AbstractString, args...; kvs...)
    extn = filename[end-2:end]
    opts = args2dict(args...; kvs...)
    if extn == "eps"
        width = get(opts,:width,config_value("eps","width"))
        height = get(opts,:height,config_value("eps","height"))
        saveeps(self, filename, width, height)
    elseif extn == "pdf"
        width = get(opts,:width,config_value("pdf","width"))
        height = get(opts,:height,config_value("pdf","height"))
        savepdf(self, filename, width, height)
    elseif extn == "png"
        width = get(opts,:width,config_value("window","width"))
        height = get(opts,:height,config_value("window","height"))
        savepng(self, filename, width, height)
    elseif extn == "svg"
        width = get(opts, :width, config_value("svg","width"))
        height = get(opts, :height, config_value("svg","height"))
        savesvg(self, filename, width, height)
    else
        error("I can't export .$extn, sorry.")
    end
end

function savefig{T<:PlotContainer}(plots::Vector{T}, filename::AbstractString, args...; kvs...)
    extn = filename[end-2:end]
    opts = args2dict(args...; kvs...)
    if extn == "pdf"
        width = get(opts,:width,config_value("pdf","width"))
        height = get(opts,:height,config_value("pdf","height"))
        savepdf(plots, filename, width, height)
    else
        error("I can't export multiple pages to .$extn, sorry.")
    end
end

function svg(self::PlotContainer, args...; kvs...)
    opts = args2dict(args...; kvs...)
    width = get(opts,:width,config_value("window","width"))
    height = get(opts,:height,config_value("window","height"))
    stream = IOBuffer()

    savesvg(self, stream, width, height)

    s = takebuf_string(stream)
    a,b = search(s, "<svg")
    s[a:end]
end

#function multipage(plots, filename, args...)
#    file = _open_output(filename)
#    opt = copy(config_options("postscript"))
#    opt.update(args...)
#    device = PSRenderer(file, opt...)
#    for plot in plots
#        page_compose(plot, device)
#    end
#    delete(device)
#    _close_output(file)
#end

# LineComponent ---------------------------------------------------------------

abstract LineComponent <: PlotComponent

_kw_rename(::LineComponent) = @Dict(
    :color => :linecolor,
    :kind => :linekind,
    :width => :linewidth,
    # deprecated
    :type => :linekind,
    :linetype => :linekind,
)

function make_key(self::LineComponent, bbox::BoundingBox)
    y = center(bbox).y
    p = Point(xmin(bbox), y)
    q = Point(xmax(bbox), y)
    GroupPainter(getattr(self,:style), LinePainter(p, q))
end

type Curve <: LineComponent
    attr::Dict
    x
    y

    function Curve(x::AbstractArray, y::AbstractArray, args...; kvs...)
        attr = Dict()
        self = new(attr, x, y)
        iniattr(self)
        kw_init(self, args...; kvs...)
        self
    end
end

limits(self::Curve, window::BoundingBox) = bounds_within(self.x, self.y, window)

function make(self::Curve, context)
    x, y = project(context.geom, self.x, self.y)
    GroupPainter(getattr(self,:style), PathPainter(x,y))
end

type Slope <: LineComponent
    attr::Dict
    slope::Real
    intercept

    function Slope(slope, intercept, args...; kvs...)
        #LineComponent.__init__(self)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.slope = slope
        self.intercept = intercept
        self
    end
end

function _x(self::Slope, y::Real)
    x0, y0 = self.intercept
    return x0 + float(y - y0) / self.slope
end

function _y(self::Slope, x::Real)
    x0, y0 = self.intercept
    return y0 + (x - x0) * self.slope
end

function make(self::Slope, context::PlotContext)
    xr = xrange(context.data_bbox)
    yr = yrange(context.data_bbox)
    if self.slope == 0
        l = Any[ Point(xr[1], self.intercept[2]),
                 Point(xr[2], self.intercept[2]) ]
    else
        l = Any[ Point(xr[1], _y(self, xr[1])),
                 Point(xr[2], _y(self, xr[2])),
                 Point(_x(self, yr[1]), yr[1]),
                 Point(_x(self, yr[2]), yr[2]) ]
    end
    m = Any[]
    for el in l
        if isinside(context.data_bbox, el)
            push!(m, el)
        end
    end
    #sort!(m)
    objs = GroupPainter(getattr(self,:style))
    if length(m) > 1
        a = project(context.geom, m[1])
        b = project(context.geom, m[end])
        push!(objs, LinePainter(a, b))
    end
    objs
end

type Histogram <: LineComponent
    attr::PlotAttributes
    edges::AbstractVector
    values::AbstractVector

    function Histogram(edges, counts, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.edges = edges
        self.values = counts
        self
    end
end

function limits(self::Histogram, window::BoundingBox)
    if getattr(self, "drop_to_zero")
        return bounds_within(self.edges, self.values, window) +
               bounds_within(self.edges, zeros(length(self.values)), window)
    else
        return bounds_within(self.edges, self.values, window)
    end
end

function make(self::Histogram, context::PlotContext)
    nval = length(self.values)
    drop_to_zero = getattr(self, "drop_to_zero")
    x = Float64[]
    y = Float64[]
    if drop_to_zero
        push!(x, first(self.edges))
        push!(y, 0.)
    end
    for i in 1:nval
        yi = self.values[i]
        push!(x, self.edges[i])
        push!(x, self.edges[i+1])
        push!(y, yi)
        push!(y, yi)
    end
    if drop_to_zero
        push!(x, last(self.edges))
        push!(y, 0.)
    end
    u, v = project(context.geom, x, y)
    GroupPainter(getattr(self,:style), PathPainter(u, v))
end

type LineX <: LineComponent
    attr::PlotAttributes
    x::Float64

    function LineX(x, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.x = x
        self
    end
end

function limits(self::LineX, window::BoundingBox)
    return BoundingBox(self.x, self.x, NaN, NaN)
end

function make(self::LineX, context::PlotContext)
    yr = yrange(context.data_bbox)
    a = project(context.geom, Point(self.x, yr[1]))
    b = project(context.geom, Point(self.x, yr[2]))
    GroupPainter(getattr(self,:style), LinePainter(a, b))
end

type LineY <: LineComponent
    attr::PlotAttributes
    y::Float64

    function LineY(y, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.y = y
        self
    end
end

function limits(self::LineY, window::BoundingBox)
    return BoundingBox(NaN, NaN, self.y, self.y)
end

function make(self::LineY, context::PlotContext)
    xr = xrange(context.data_bbox)
    a = project(context.geom, Point(xr[1], self.y))
    b = project(context.geom, Point(xr[2], self.y))
    GroupPainter(getattr(self,:style), LinePainter(a, b))
end

type BoxLabel <: PlotComponent
    attr::PlotAttributes
    obj
    str::AbstractString
    side
    offset

    function BoxLabel(obj, str::AbstractString, side, offset, args...; kvs...)
        @assert !is(str,nothing)
        self = new(Dict(), obj, str, side, offset)
        kw_init(self, args...; kvs...)
        self
    end
end

_kw_rename(::BoxLabel) = @Dict(
    :face => :fontface,
    :size => :fontsize,
)

function make(self::BoxLabel, context)
    bb = boundingbox(self.obj, context.paintc)
    offset = _size_relative(self.offset, context.dev_bbox)
    if self.side == "top"
        p = upperleft(bb)
        q = upperright(bb)
    elseif self.side == "bottom"
        p = lowerleft(bb)
        q = lowerright(bb)
        offset = -offset
    elseif self.side == "left"
        p = lowerleft(bb)
        q = upperleft(bb)
    elseif self.side == "right"
        p = upperright(bb)
        q = lowerright(bb)
    end

    midpoint = 0.5*(p + q)
    direction = q - p
    direction /= norm(direction)
    angle = atan2(direction.y, direction.x)
    direction = rotate(direction, pi/2)
    pos = midpoint + offset*direction

    valign = (offset > 0) ? "bottom" : "top"
    tp = TextPainter(pos, self.str; angle=angle*180./pi, valign=valign)
    GroupPainter(getattr(self,:style), tp)
end

type Stems <: LineComponent
    attr::PlotAttributes
    x
    y

    function Stems(x, y, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.x = x
        self.y = y
        self
    end
end

function limits(self::Stems, window::BoundingBox)
    return bounds_within(self.x, self.y, window) +
           bounds_within(self.x, zeros(length(self.y)), window)
end

function make(self::Stems, context::PlotContext)
    gp = GroupPainter(getattr(self,:style))
    n = min(length(self.x),length(self.y))
    for i = 1:n
        a = project(context.geom, Point(self.x[i],self.y[i]))
        b = project(context.geom, Point(self.x[i],0.))
        push!(gp, LinePainter(a,b))
    end
    gp
end

# LabelComponent --------------------------------------------------------------

abstract LabelComponent <: PlotComponent

_kw_rename(::LabelComponent) = @Dict(
    :face      => :fontface,
    :size      => :fontsize,
    :angle     => :textangle,
    :halign    => :texthalign,
    :valign    => :textvalign,
)

#function limits(self::LabelComponent)
#    return BoundingBox()
#end

type DataLabel <: LabelComponent
    attr::PlotAttributes
    pos::Point
    str::AbstractString

    function DataLabel(x, y, str, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.pos = Point(x, y)
        self.str = str
        self
    end
end

function make(self::DataLabel, context)
    xy = project(context.geom, self.pos)
    # XXX:fix angle,halign,valign so that default values are not send forward
    textangle=kw_get(self,:textangle,0.0)
    texthalign=kw_get(self,:texthalign,"center")
    textvalign=kw_get(self,:textvalign,"center")

    tp = TextPainter(xy, self.str; angle=textangle,halign=texthalign,valign=textvalign)
    GroupPainter(getattr(self,:style), tp)
end

type PlotLabel <: LabelComponent
    attr::PlotAttributes
    pos::Point
    str::AbstractString

    function PlotLabel(x, y, str, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.pos = Point(x, y)
        self.str = str
        self
    end
end

function make(self::PlotLabel, context)
    pos = project(context.plot_geom, self.pos)
    # XXX:fix angle,halign,valign so that default values are not send forward
    textangle=kw_get(self,:textangle,0.0)
    texthalign=kw_get(self,:texthalign,"center")
    textvalign=kw_get(self,:textvalign,"center")

    tp = TextPainter(pos, self.str; angle=textangle,halign=texthalign,valign=textvalign)
    GroupPainter(getattr(self,:style), tp)
end

# LabelsComponent ------------------------------------------------------------
#
#type Labels <: _PlotComponent
#
#    function __init__(self, x, y, labels, args...)
#        _PlotComponent.__init__(self)
#        self.iniattr("LabelsComponent")
#        self.iniattr("Labels")
#        kw_init(self, args...; kvs...)
#        self.x = x
#        self.y = y
#        self.labels = labels
#    end
#end
#
#_kw_rename(::Labels) = [
#    "face"      => "fontface",
#    "size"      => "fontsize",
#]
#
#function limits(self::Labels)
#    p = min(self.x), min(self.y)
#    q = max(self.x), max(self.y)
#    return BoundingBox(p, q)
#end
#
#function make(self::Labels, context::PlotContext)
#    x, y = project(context.geom, self.x, self.y)
#    l = LabelsPainter(zip(x,y), self.labels, self.kw_style)
#    add(self, l)
#end

# FillComponent -------------------------------------------------------------

abstract FillComponent <: PlotComponent

function make_key(self::FillComponent, bbox::BoundingBox)
    p = lowerleft(bbox)
    q = upperright(bbox)
    return GroupPainter(getattr(self,:style), BoxPainter(p,q))
end

kw_defaults(::FillComponent) = @Dict(
    :color => config_value("FillComponent","fillcolor"),
    :fillkind => config_value("FillComponent","fillkind"),
)

type FillAbove <: FillComponent
    attr::PlotAttributes
    x
    y

    function FillAbove(x, y, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.x = x
        self.y = y
        self
    end
end

limits(self::FillAbove, window::BoundingBox) = bounds_within(self.x, self.y, window)

function make(self::FillAbove, context)
    coords = map((a,b)->project(context.geom,Point(a,b)), self.x, self.y)
    max_y = ymax(context.data_bbox)
    push!(coords, project(context.geom, Point(self.x[end], max_y)))
    push!(coords, project(context.geom, Point(self.x[1], max_y)))
    GroupPainter(getattr(self,:style), PolygonPainter(coords))
end

type FillBelow <: FillComponent
    attr::PlotAttributes
    x
    y

    function FillBelow(x, y, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.x = x
        self.y = y
        self
    end
end

limits(self::FillBelow, window::BoundingBox) = bounds_within(self.x, self.y, window)

function make(self::FillBelow, context)
    coords = map((a,b)->project(context.geom,Point(a,b)), self.x, self.y)
    min_y = ymin(context.data_bbox)
    push!(coords, project(context.geom, Point(self.x[end], min_y)))
    push!(coords, project(context.geom, Point(self.x[1], min_y)))
    GroupPainter(getattr(self,:style), PolygonPainter(coords))
end

type FillBetween <: FillComponent
    attr::PlotAttributes
    x1
    y1
    x2
    y2

    function FillBetween(x1, y1, x2, y2, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self
    end
end

limits(self::FillBetween, window::BoundingBox) =
    bounds_within(self.x1, self.y1, window) +
    bounds_within(self.x2, self.y2, window)

function make(self::FillBetween, context)
    x = [self.x1; reverse(self.x2)]
    y = [self.y1; reverse(self.y2)]
    coords = map((a,b) -> project(context.geom,Point(a,b)), x, y)
    GroupPainter(getattr(self,:style), PolygonPainter(coords))
end

# ImageComponent -------------------------------------------------------------

abstract ImageComponent <: PlotComponent

type Image <: ImageComponent
    attr::PlotAttributes
    img
    x
    y
    w
    h

    function Image(xrange, yrange, img, args...; kvs...)
        x = minimum(xrange)
        y = minimum(yrange)
        w = abs(xrange[2] - xrange[1])
        h = abs(yrange[2] - yrange[1])
        self = new(Dict(), img, x, y, w, h)
        iniattr(self)
        kw_init(self, args...; kvs...)
        self
    end
end

limits(self::Image, window::BoundingBox) =
    bounds_within([self.x, self.x+self.w], [self.y, self.y+self.h], window)

function make(self::Image, context)
    a = project(context.geom, Point(self.x, self.y))
    b = project(context.geom, Point(self.x+self.w, self.y+self.h))
    bbox = BoundingBox(a, b)
    GroupPainter(getattr(self,:style), ImagePainter(self.img, bbox))
end

# FramedComponent ---------------------------------------------------------------

abstract FramedComponent <: PlotComponent
    
function make_key(self::FramedComponent, bbox::BoundingBox)
    p = lowerleft(bbox)
    q = upperright(bbox)
    GroupPainter(getattr(self, :style), BoxPainter(p, q))
end

_kw_rename(::FramedComponent) = @Dict(:color => :fillcolor)

# FramedBar ------------------------------------------------------------------

type FramedBar <: FramedComponent
    attr::PlotAttributes
    g::AbstractVector
    h::AbstractVecOrMat

    function FramedBar(g, h, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.g = map(string, g)
        self.h = h
        self
    end
end

_kw_rename(::FramedBar) = @Dict(
    :color => :fillcolor,
    :width => :barwidth,
)

function limits(self::FramedBar, window::BoundingBox)
    x = [1, length(self.g)] + 
        getattr(self, "barwidth") * [-.5, .5] +
        getattr(self, "offset")
    y = [extrema(self.h)...]
    !getattr(self, "vertical") && ((x, y) = (y, x))
    bounds_within(x, y, window)
end

function make(self::FramedBar, context)
    style = getattr(self, :style)
    objs = GroupPainter(style)
    baseline = getattr(self, "baseline")
    x = collect(1:length(self.h)) .+ getattr(self, "barwidth") * [-.5 .5] + getattr(self, "offset")
    y = [baseline .* ones(length(self.h)) self.h]
    if !getattr(self, "vertical")
        x, y = y, x
        bl = LineX(baseline)
    else
        bl = LineY(baseline)
    end
    for i = 1:length(self.h)
        corners = [project(context.geom, Point(x[i,c], y[i,c])) for c in (1,2)]
        push!(objs, BoxPainter(corners...))
    end
    if haskey(style, :draw_baseline) && style[:draw_baseline]
        objs = GroupPainter(objs, make(bl, context))
    end
    objs
end

# SymbolDataComponent --------------------------------------------------------

abstract SymbolDataComponent <: PlotComponent

_kw_rename(::SymbolDataComponent) = @Dict(
    :kind => :symbolkind,
    :size => :symbolsize,
    # deprecated
    :type => :symbolkind,
    :symboltype => :symbolkind,
)

function make_key(self::SymbolDataComponent, bbox::BoundingBox)
    pos = center(bbox)
    return GroupPainter(getattr(self,:style), SymbolPainter(pos))
end

type Points <: SymbolDataComponent
    attr::PlotAttributes
    x
    y

    function Points(x, y, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.x = x
        self.y = y
        self
    end
end

kw_defaults(::SymbolDataComponent) = @Dict(
    :symbolkind => config_value("Points","symbolkind"),
    :symbolsize => config_value("Points","symbolsize"),
)

limits(self::SymbolDataComponent, window::BoundingBox) =
    bounds_within(self.x, self.y, window)

function make(self::SymbolDataComponent, context::PlotContext)
    x, y = project(context.geom, self.x, self.y)
    GroupPainter(getattr(self,:style), SymbolsPainter(x,y))
end

function Points(x::Real, y::Real, args...)
    return Points([x], [y], args...)
end

type ColoredPoints <: SymbolDataComponent
    attr::PlotAttributes
    x
    y
    s
    c

    function ColoredPoints(x, y, s, c, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.x = x
        self.y = y
        self.s = s
        self.c = c
        self
    end
end

kw_defaults(::ColoredPoints) = @Dict(
    :symbolkind => config_value("Points","symbolkind"),
    :symbolsize => config_value("Points","symbolsize"),
)

limits(self::ColoredPoints, window::BoundingBox) =
    bounds_within(self.x, self.y, window)

function make(self::ColoredPoints, context::PlotContext)
    x, y = project(context.geom, self.x, self.y)
    GroupPainter(getattr(self,:style), ColoredSymbolsPainter(x, y, self.s, self.c))
end

function ColoredPoints(x::Real, y::Real, args...)
    return ColoredPoints([x], [y], args...)
end

# PlotComponent ---------------------------------------------------------------

function show(io::IO, self::PlotComponent)
    print(io, typeof(self), "(...)")
end

function limits(self::PlotComponent, window::BoundingBox)
    return BoundingBox()
end

function make_key(self::PlotComponent, bbox::BoundingBox)
end

function boundingbox(self::PlotComponent, context::PlotContext)
    objs = make(self, context)
    boundingbox(objs, context.paintc)
end

function render(self::PlotComponent, context)
    objs = make(self, context)
    paint(objs, context.paintc)
end

# HasAttr ---------------------------------------------------------------------

_attr_map(::HasAttr) = Dict()

function hasattr(self::HasAttr, name::Symbol)
    key = get(_attr_map(self), name, name)
    return haskey(self.attr, key)
end

function getattr(self::HasAttr, name::Symbol)
    key = get(_attr_map(self), name, name)
    return self.attr[key]
end

function getattr(self::HasAttr, name::Symbol, notfound)
    key = get(_attr_map(self), name, name)
    return haskey(self.attr,key) ? self.attr[key] : notfound
end

function setattr(self::HasAttr, name::Symbol, value)
    key = get(_attr_map(self), name, name)
    self.attr[key] = value
end

hasattr(self::HasAttr, name::AbstractString) = hasattr(self, symbol(name))
getattr(self::HasAttr, name::AbstractString) = getattr(self, symbol(name))
getattr(self::HasAttr, name::AbstractString, notfound) = getattr(self, symbol(name), notfound)
setattr(self::HasAttr, name::AbstractString, value) = setattr(self, symbol(name), value)
setattr(self::HasAttr; kvs...) = (for (k,v) in kvs; setattr(self, k, v); end)

function iniattr(self::HasAttr, args...; kvs...)
    types = Any[typeof(self)]
    while super(types[end]) != Any
        push!(types, super(types[end]))
    end
    for t in reverse(types)
        name = last(split(string(t), '.'))
        for (k,v) in config_options(name)
            setattr(self, k, v)
        end
    end
    for (k,v) in args2dict(args...)
        setattr(self, k, v)
    end
    for (k,v) in kvs
        setattr(self, k, v)
    end
end

# HasStyle ---------------------------------------------------------------

kw_defaults(x) = Dict{Symbol,Any}()
_kw_rename(x) = Dict{Symbol,Symbol}()

function kw_init(self::HasStyle, args...; kvs...)
    # jeez, what a mess...
    sty = Dict{Symbol,Any}()
    for (k,v) in kw_defaults(self)
        sty[k] = v
    end
    if hasattr(self, :kw_defaults)
        for (k,v) in getattr(self, :kw_defaults)
            sty[k] = v
        end
    end
    setattr(self, :style, sty)
    for (key, value) in args2dict(args...)
        kw_set(self, key, value)
    end
    for (k,v) in kvs
        kw_set(self, k, v)
    end
end

function kw_set(self::HasStyle, name, value)
    #if !hasattr(self, "style")
    #    kw_init(self)
    #end
    key = get(_kw_rename(self), name, name)
    getattr(self, :style)[key] = value
end

function style(self::HasStyle, args...; kvs...)
    for (key,val) in args2dict(args...)
        kw_set(self, key, val)
    end
    for (key,val) in kvs
        kw_set(self, key, val)
    end
end

kw_get(self::HasStyle, key) = kw_get(self, key, nothing)
function kw_get(self::HasStyle, key, notfound)
    return get(getattr(self,:style), key, notfound)
end

include("plot.jl")
include("plot_interfaces.jl")
include("contour.jl")

############################################################################

_ijulia_width = 450
_ijulia_height = 300
function set_default_plot_size(width::Int, height::Int)
    global _ijulia_width
    global _ijulia_height
    _ijulia_width = width
    _ijulia_height = height
end

writemime(io::IO, ::MIME"image/png", p::PlotContainer) =
    savepng(p, io, _ijulia_width, _ijulia_height)

if isdefined(Main, :IJulia)
    output_surface = :none
else
    output_surface = Winston.config_value("default","output_surface")
    output_surface = symbol(lowercase(get(ENV, "WINSTON_OUTPUT", output_surface)))
end

type Figure
    window
    plot::PlotContainer
end

type WinstonDisplay <: Display
    figs::Dict{Int,Figure}
    fig_order::Vector{Int}
    current_fig::Int
    next_fig::Int
    WinstonDisplay() = new(Dict{Int,Figure}(), Int[], 0, 1)
end

function addfig(d::WinstonDisplay, i::Int, fig::Figure)
    @assert !haskey(d.figs,i)
    d.figs[i] = fig
    push!(d.fig_order, i)
    while haskey(d.figs,d.next_fig)
        d.next_fig += 1
    end
    d.current_fig = i
end

hasfig(d::WinstonDisplay, i::Int) = haskey(d.figs,i)

function switchfig(d::WinstonDisplay, i::Int)
    haskey(d.figs,i) && (d.current_fig = i)
end

function getfig(d::WinstonDisplay, i::Int)
    haskey(d.figs,i) ? d.figs[i] : error("no figure with index $i")
end

function curfig(d::WinstonDisplay)
    d.figs[d.current_fig]
end

nextfig(d::WinstonDisplay) = d.next_fig

function dropfig(d::WinstonDisplay, i::Int)
    haskey(d.figs,i) || return
    delete!(d.figs, i)
    splice!(d.fig_order, findfirst(d.fig_order,i))
    d.next_fig = min(d.next_fig, i)
    d.current_fig = isempty(d.fig_order) ? 0 : d.fig_order[end]
end

_display = WinstonDisplay()
_pwinston = FramedPlot()

function figure(;name::AbstractString="Figure $(nextfig(_display))",
                 width::Integer=Winston.config_value("window","width"),
                 height::Integer=Winston.config_value("window","height"))
    i = nextfig(_display)
    w = window(name, width, height, (x...)->dropfig(_display,i))
    isempty(_display.figs) || (global _pwinston = FramedPlot())
    addfig(_display, i, Figure(w,_pwinston))
end

function figure(i::Integer)
    switchfig(_display, i)
    fig = curfig(_display)
    global _pwinston = fig.plot
    display(_display, fig)
    nothing
end

gcf() = _display.current_fig
closefig() = closefig(_display.current_fig)

if output_surface != :none
    if output_surface == :gtk
        include("gtk.jl")
        window = gtkwindow
        closefig(i::Integer) = gtkdestroy(getfig(_display,i).window)
        closeall() = (map(closefig, keys(_display.figs)); nothing)
    elseif output_surface == :tk
        include("tk.jl")
        window = tkwindow
        closefig(i::Integer) = tkdestroy(getfig(_display,i).window)
        closeall() = (map(closefig, keys(_display.figs)); nothing)
    else
        warn("Selected Winston backend not found. You will not be able to display plots in a window")
    end
    display(d::WinstonDisplay, f::Figure) = display(f.window, f.plot)
    function display(d::WinstonDisplay, p::PlotContainer)
        isempty(d.figs) && figure()
        f = curfig(d)
        f.plot = p
        display(d, f)
    end
    pushdisplay(_display)
    if VERSION >= v"0.3-"
        display(::Base.REPL.REPLDisplay, ::MIME"text/plain", p::PlotContainer) = display(p)
    end
end

end # module
