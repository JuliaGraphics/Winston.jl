module Winston

using Cairo
using Color
importall Base.Graphics
using IniFile

import Base.getindex, Base.setindex!, Base.+, Base.-, Base.add, Base.isempty,
       Base.copy, Base.(*), Base.(/), Base.get, Base.show

export PlotContainer
export Curve, FillAbove, FillBelow, FillBetween, Histogram, Image, Legend,
    LineX, LineY, PlotInset, PlotLabel, Points, Slope,
    SymmetricErrorBarsX, SymmetricErrorBarsY
export FramedArray, FramedPlot, Table
export file, getattr, setattr, style, svg
export get_context, device_to_data, data_to_device

abstract HasAttr
abstract HasStyle <: HasAttr
abstract PlotComponent <: HasStyle
abstract PlotContainer <: HasAttr

typealias PlotAttributes Associative # TODO: does Associative need {K,V}?

include("config.jl")
include("renderer.jl")

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

function _first_not_none(args...)
    for arg in args
	if !is(arg,nothing)
	    return arg
        end
    end
    return nothing
end

# NOTE: these are not standard, since where a coordinate falls on the screen
# depends on the current transformation.
lowerleft(bb::BoundingBox) = Point(bb.xmin, bb.ymin)
upperleft(bb::BoundingBox) = Point(bb.xmin, bb.ymax)
lowerright(bb::BoundingBox) = Point(bb.xmax, bb.ymin)
upperright(bb::BoundingBox) = Point(bb.xmax, bb.ymax)

maxfinite(A) = maximum(A)
maxfinite(x, y) = max(x, y)
function maxfinite{T<:FloatingPoint}(A::AbstractArray{T})
    ret = nan(T)
    for a in A
        ret = isfinite(a) ? (ret > a ? ret : a) : ret
    end
    ret
end
function maxfinite(x::FloatingPoint, y::FloatingPoint)
    ifx = isfinite(x)
    ify = isfinite(y)
    if ifx && ify
        return max(x, y)
    elseif ifx
        return x
    end
    y
end
maxfinite(x::FloatingPoint, y) = isfinite(x) ? max(x, y) : y
maxfinite(x, y::FloatingPoint) = isfinite(y) ? max(x, y) : x

minfinite(A) = minimum(A)
minfinite(x, y) = min(x, y)
function minfinite{T<:FloatingPoint}(A::AbstractArray{T})
    ret = nan(T)
    for a in A
        ret = isfinite(a) ? (ret < a ? ret : a) : ret
    end
    ret
end
function minfinite(x::FloatingPoint, y::FloatingPoint)
    ifx = isfinite(x)
    ify = isfinite(y)
    if ifx && ify
        return min(x, y)
    elseif ifx
        return x
    end
    y
end
minfinite(x::FloatingPoint, y) = isfinite(x) ? min(x, y) : y
minfinite(x, y::FloatingPoint) = isfinite(y) ? min(x, y) : x

include("geom.jl")

# relative size ---------------------------------------------------------------

function _size_relative(relsize, bbox::BoundingBox)
    w = width(bbox)
    h = height(bbox)
    yardstick = sqrt(8.) * w * h / (w + h)
    return (float(relsize)/100.) * yardstick
end

function _fontsize_relative(relsize, bbox::BoundingBox, device_bbox::BoundingBox)
    devsize = _size_relative(relsize, bbox)
    fontsize_min = config_value("default", "fontsize_min")
    devsize_min = _size_relative(fontsize_min, device_bbox)
    return max(devsize, devsize_min)
end

# PlotContext -------------------------------------------------------------

type PlotContext
    draw
    dev_bbox::BoundingBox
    data_bbox::BoundingBox
    xlog::Bool
    ylog::Bool
    geom::Projection
    plot_geom::Projection

    function PlotContext(device::Renderer, dev::BoundingBox, data::BoundingBox, proj::Projection, xlog, ylog)
        new(
            device,
            dev,
            data,
            xlog,
            ylog,
            proj,
            PlotGeometry(0, 1, 0, 1, dev)
       )
    end

    PlotContext(device, dev, data, proj) = PlotContext(device, dev, data, proj, false, false)
end

function _kw_func_relative_fontsize(context::PlotContext, key, value)
    device_size = _fontsize_relative(value, context.dev_bbox, boundingbox(context.draw))
    set(context.draw, key, device_size)
end

function _kw_func_relative_size(context::PlotContext, key, value)
    device_size = _size_relative(value, context.dev_bbox)
    set(context.draw, key, device_size)
end

function _kw_func_relative_width(context::PlotContext, key, value)
    device_width = _size_relative(value/10., context.dev_bbox)
    set(context.draw, key, device_width)
end

_kw_func = [
    :fontsize => _kw_func_relative_fontsize,
    :linewidth => _kw_func_relative_width,
    :symbolsize => _kw_func_relative_size,
]
function push_style(context::PlotContext, style)
    save_state(context.draw)
    if !is(style,nothing)
        for (key, value) in style
            if haskey(_kw_func, key)
                method = _kw_func[key]
                method(context, key, value)
            else
                set(context.draw, key, value)
            end
        end
    end
end

function pop_style(context::PlotContext)
    restore_state(context.draw)
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
    aff = ctx.geom.aff
    h = height(ctx.draw)
    xu = (x - aff.t[1])/aff.m[1,1]
    yu = ((h-y) - aff.t[2])/aff.m[2,2]
    xu, yu
end

function data_to_device{T<:Real}(ctx::PlotContext, x::Union(T,AbstractArray{T}), y::Union(T,AbstractArray{T}))
    aff = ctx.geom.aff
    h = height(ctx.draw)
    xdev = aff.t[1] + x*aff.m[1,1]
    ydev = h - (aff.t[2] + y*aff.m[2,2])
    xdev, ydev
end

include("paint.jl")

# =============================================================================
#
# PlotObjects
#
# =============================================================================

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

_kw_rename(::Legend) = [
    :face      => :fontface,
    :size      => :fontsize,
    :angle     => :textangle,
    :halign    => :texthalign,
    :valign    => :textvalign,
]

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

    objs = {}
    for comp in self.components
        s = getattr(comp, "label", "")
        t = TextObject(text_pos, s, getattr(self,"style"); halign=halign)
        push!(objs, t)
        push!(objs, make_key(comp,bbox))
        text_pos = text_pos + dp
        bbox = shift(bbox, dp.x, dp.y)
    end
    objs
end

# ErrorBars --------------------------------------------------------------------

abstract ErrorBar <: PlotComponent

_kw_rename(::ErrorBar) = [
    :color => :linecolor,
    :width => :linewidth,
    :kind => :linekind,
]

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

function limits(self::ErrorBarsX)
    return BoundingBox(minfinite(minfinite(self.lo), minfinite(self.hi)),
                       maxfinite(maxfinite(self.lo), maxfinite(self.hi)),
                       minfinite(self.y),
                       maxfinite(self.y))
end

function make(self::ErrorBarsX, context)
    l = _size_relative(getattr(self, "barsize"), context.dev_bbox)
    objs = {}
    for i = 1:length(self.y)
        p = project(context.geom, self.lo[i], self.y[i])
        q = project(context.geom, self.hi[i], self.y[i])
        l0 = LineObject(Point(p[1],p[2]), Point(q[1],q[2]))
        l1 = LineObject(Point(p[1],p[2]-l), Point(p[1],p[2]+l))
        l2 = LineObject(Point(q[1],q[2]-l), Point(q[1],q[2]+l))
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

function limits(self::ErrorBarsY)
    return BoundingBox(minfinite(self.x),
                       maxfinite(self.x),
                       minfinite(minfinite(self.lo), minfinite(self.hi)),
                       maxfinite(maxfinite(self.lo), maxfinite(self.hi)))
end

function make(self::ErrorBarsY, context)
    objs = {}
    l = _size_relative(getattr(self, "barsize"), context.dev_bbox)
    for i = 1:length(self.x)
        p = project(context.geom, self.x[i], self.lo[i])
        q = project(context.geom, self.x[i], self.hi[i])
        l0 = LineObject(Point(p[1],p[2]), Point(q[1],q[2]))
        l1 = LineObject(Point(p[1]-l,p[2]), Point(p[1]+l,p[2]))
        l2 = LineObject(Point(q[1]-l,q[2]), Point(q[1]+l,q[2]))
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

function limits(self::DataInset)
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

function limits(self::PlotInset)
    return self.plot_limits
end

# HalfAxis --------------------------------------------------------------------

function _magform(x)
    # Given x, returns (a,b), where x = a*10^b [a >= 1., b integral].
    if x == 0
        return 0., 0
    end
    a, b = modf(log10(abs(x)))
    a, b = 10^a, int(b)
    if a < 1.
        a, b = a * 10, b - 1
    end
    if x < 0.
        a = -a
    end
    return a, b
end

_format_ticklabel(x) = _format_ticklabel(x, 0.)
function _format_ticklabel(x, range)
    if x == 0
        return "0"
    end
    neg, digits, b = Base.Grisu.grisu(x, Base.Grisu.SHORTEST, int32(0))
    if length(digits) > 5
        neg, digits, b = Base.Grisu.grisu(x, Base.Grisu.PRECISION, int32(6))
        n = length(digits)
        while digits[n] == '0'
            n -= 1
        end
        digits = digits[1:n]
    end
    b -= 1
    if abs(b) > 4
        s = IOBuffer()
        if neg write(s, '-') end
        if digits != [0x31]
            write(s, char(digits[1]))
            if length(digits) > 1
                write(s, '.')
                for i = 2:length(digits)
                    write(s, char(digits[i]))
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

range(a::Integer, b::Integer) = (a <= b) ? (a:b) : (a:-1:b)

_ticklist_linear(lo, hi, sep) = _ticklist_linear(lo, hi, sep, 0.)
function _ticklist_linear(lo, hi, sep, origin)
    l = (lo - origin)/sep
    h = (hi - origin)/sep
    a, b = (l <= h) ? (iceil(l),ifloor(h)) : (ifloor(l),iceil(h))
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
    log_lim = log10(lim[1]), log10(lim[2])
    nlo = iceil(log10(lim[1]))
    nhi = ifloor(log10(lim[2]))
    nn = nhi - nlo +1

    if nn >= 10
        return [ 10.0^x for x=_ticks_default_linear(log_lim) ]
    elseif nn >= 2
        return [ 10.0^i for i=nlo:nhi ]
    else
        return _ticks_default_linear(lim)
    end
end

function _ticks_num_linear(lim, num)
    a = lim[1]
    b = (lim[2] - lim[1])/float(num-1)
    [ a + i*b for i=0:num-1 ]
end

function _ticks_num_log(lim, num)
    a = log10(lim[1])
    b = (log10(lim[2]) - a)/float(num - 1)
    [ 10.0^(a + i*b) for i=0:num-1 ]
end

_subticks_linear(lim, ticks) = _subticks_linear(lim, ticks, nothing)
function _subticks_linear(lim, ticks, num)
    major_div = (ticks[end] - ticks[1])/float(length(ticks) - 1)
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

_subticks_log(lim, ticks) = _subticks_log(lim, ticks, nothing)
function _subticks_log(lim, ticks, num)
    log_lim = log10(lim[1]), log10(lim[2])
    nlo = iceil(log10(lim[1]))
    nhi = ifloor(log10(lim[2]))
    nn = nhi - nlo +1

    if nn >= 10
        return [ 10.0^x for x in _subticks_linear(log_lim, map(log10,ticks), num) ]
    elseif nn >= 2
        minor_ticks = Float64[]
        for i in (nlo-1):nhi
            for j in 1:9
                z = j * 10.0^i
                if lim[1] <= z && z <= lim[2]
                    push!(minor_ticks, z)
                end
            end
        end
        return minor_ticks
    else
        return _subticks_linear(lim, ticks, num)
    end
end

type _Group
    objs

    function _Group(objs)
        #self.objs = objs[:]
        new(copy(objs))
    end    
end

function boundingbox(self::_Group, context)
    bb = BoundingBox()
    for obj in self.objs
        bb += boundingbox(obj, context)
    end
    return bb
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
    if (getattr(self, "ticklabels_dir") < 0) #$ context.geom.yflipped
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
    if isequal(ticks,nothing)
        return
    end
    objs = {}
    for tick in ticks
        push!(objs, LineX(tick,getattr(self, "grid_style")))
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
    if (getattr(self, "ticklabels_dir") > 0) $ context.geom.xflipped
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
    if isequal(ticks,nothing)
        return
    end
    objs = {}
    for tick in ticks
        push!(objs, LineY(tick,getattr(self,"grid_style")))
    end
    objs
end

# defaults

_attr_map(::HalfAxis) = [
    :labeloffset       => :label_offset,
    :major_ticklabels  => :ticklabels,
    :major_ticks       => :ticks,
    :minor_ticks       => :subticks,
]

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
        return
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

    style = (Symbol=>Any)[]
    style[:texthalign] = halign
    style[:textvalign] = valign
    for (k,v) in getattr(self, :ticklabels_style)
        style[k] = v
    end

    LabelsObject(labelpos, labels, style; halign=style[:texthalign], valign=style[:textvalign])
end

function _make_spine(self::HalfAxis, context)
    a, b = _range(self, context)
    p = _pos(self, context, a)
    q = _pos(self, context, b)
    LineObject(p, q, getattr(self, "spine_style"))
end

function _make_ticks(self::HalfAxis, context, ticks, size, style)
    if isequal(ticks,nothing) || length(ticks) <= 0
        return
    end

    dir = getattr(self, "tickdir") * getattr(self, "ticklabels_dir")
    ticklen = _dpos(self, dir * _size_relative(size, context.dev_bbox))

    tickpos = Point[ _pos(self, context, tick) for tick in ticks ]

    CombObject(tickpos, ticklen, style)
end

function make(self::HalfAxis, context)
    if getattr(self, "draw_nothing")
        return {}
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

    objs = {}
    if getattr(self, "draw_grid")
        objs = _make_grid(self, context, ticks)
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
            push!(objs, BoxLabel(
                _Group(objs),
                getattr(self, "label"),
                _side(self),
                getattr(self, "label_offset"),
                getattr(self, "label_style")))
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
        self = new(Dict(), {}, false)
        kw_init(self, args...; kvs...)
        self
    end
end

function add(self::PlotComposite, args::PlotComponent...)
    for arg in args
        push!(self.components, arg)
    end
end

function clear(self::PlotComposite)
    self.components = {}
end

function isempty(self::PlotComposite)
    return isempty(self.components)
end

function limits(self::PlotComposite)
    bb = BoundingBox()
    for obj in self.components
        bb += limits(obj)
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
    push_style(context, getattr(self,"style"))
    if !self.dont_clip
        set(context.draw, "cliprect", context.dev_bbox)
    end
    for obj in self.components
        render(obj, context)
    end
    pop_style(context)
end

# -----------------------------------------------------------------------------

function _limits_axis(content_range, gutter, user_range, is_log::Bool)

    r0, r1 = 0, 1

    if !is(content_range,nothing)
        a, b = content_range
        if !is(a,nothing)
            r0 = a
        end
        if !is(b,nothing)
            r1 = b
        end
    end

    if !is(gutter,nothing)
        dx = 0.5 * gutter * (r1 - r0)
        a = r0 - dx
        if ! is_log || a > 0
            r0 = a
        end
        r1 = r1 + dx
    end

    if !is(user_range,nothing)
        a, b = user_range
        if !is(a,nothing)
            r0 = a
        end
        if !is(b,nothing)
            r1 = b
        end
    end

    if r0 == r1
        r0 = r0 - 1
        r1 = r1 + 1
    end

    return r0, r1
end

function _limits(content_bbox::BoundingBox, gutter, xlog, ylog, xr0, yr0)
    xr = _limits_axis(xrange(content_bbox), gutter, xr0, xlog)
    yr = _limits_axis(yrange(content_bbox), gutter, yr0, ylog)
    return BoundingBox(xr[1], xr[2], yr[1], yr[2])
end

# FramedPlot ------------------------------------------------------------------

type _Alias <: HasAttr
    objs
    _Alias(args...) = new(args)
end

#function project(self, args...) #,  args...)
#    for obj in self.objs
#        apply(obj, args, args...)
#    end
#end

#function getattr(self::_Alias, name)
#    objs = []
#    for obj in self.objs
#        objs.append(getattr(obj, name))
#    end
#    return apply(_Alias, objs)
#end

function setattr(self::_Alias, name::Symbol, value)
    for obj in self.objs
        setattr(obj, name, value)
    end
end

#function __setitem__(self, key, value)
#    for obj in self.objs
#        obj[key] = value
#    end
#end

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
        setattr(self.frame, :grid_style, ["linekind" => "dot"])
        setattr(self.frame, :tickdir, -1)
        setattr(self.frame1, :draw_grid, false)
        iniattr(self, args...; kvs...)
        self
    end
end

_attr_map(fp::FramedPlot) = [
    :xlabel    => (fp.x1, :label),
    :ylabel    => (fp.y1, :label),
    :xlog      => (fp.x1, :log),
    :ylog      => (fp.y1, :log),
    :xrange    => (fp.x1, :range),
    :yrange    => (fp.y1, :range),
    :xtitle    => (fp.x1, :label),
    :ytitle    => (fp.y1, :label),
]

function getattr(self::FramedPlot, name::Symbol)
    am = _attr_map(self)
    if haskey(am, name)
        a,b = am[name]
        #obj = self
        #for x in xs[:-1]
        #    obj = getattr(obj, x)
        #end
        return getattr(a, b)
    else
        return self.attr[name]
    end
end

function setattr(self::FramedPlot, name::Symbol, value)
    am = _attr_map(self)
    if haskey(am, name)
        a,b = am[name]
        #obj = self
        #for x in xs[:-1]
        #    obj = getattr(obj, x)
        #end
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
end

function add2(self::FramedPlot, args::PlotComponent...)
    add(self.content2, args...)
end

function _context1(self::FramedPlot, device::Renderer, region::BoundingBox)
    xlog = getattr(self.x1, "log")
    ylog = getattr(self.y1, "log")
    gutter = getattr(self, "gutter")
    l1 = limits(self.content1)
    xr = _limits_axis(xrange(l1), gutter, getattr(self.x1,"range"), xlog)
    yr = _limits_axis(yrange(l1), gutter, getattr(self.y1,"range"), ylog)
    lims = BoundingBox(xr[1], xr[2], yr[1], yr[2])
    proj = PlotGeometry(xr..., yr..., region, xlog, ylog)
    return PlotContext(device, region, lims, proj, xlog, ylog)
end

function _context2(self::FramedPlot, device::Renderer, region::BoundingBox)
    xlog = _first_not_none(getattr(self.x2, "log"), getattr(self.x1, "log"))
    ylog = _first_not_none(getattr(self.y2, "log"), getattr(self.y1, "log"))
    gutter = getattr(self, "gutter")
    l2 = isempty(self.content2) ? limits(self.content1) : limits(self.content2)
    xr = _first_not_none(getattr(self.x2, "range"), getattr(self.x1, "range"))
    yr = _first_not_none(getattr(self.y2, "range"), getattr(self.y1, "range"))
    xr = _limits_axis(xrange(l2), gutter, xr, xlog)
    yr = _limits_axis(yrange(l2), gutter, yr, ylog)
    lims = BoundingBox(xr[1], xr[2], yr[1], yr[2])
    proj = PlotGeometry(xr..., yr..., region, xlog, ylog)
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
    modified

    function Table(rows, cols, args...)
        self = new(Dict())
        iniattr(self, args...)
        self.rows = rows
        self.cols = cols
        self.content = cell(rows, cols)
        self.modified = false # XXX:fixme
        self
    end
end

function getindex(self::Table, row::Int, col::Int)
    return self.content[row,col]
end

function setindex!(self::Table, obj::PlotContainer, row::Int, col::Int)
    self.content[row,col] = obj
    self.modified = true # XXX:fixme
end

isempty(self::Table) = !self.modified

function exterior(self::Table, device::Renderer, intbbox::BoundingBox)
    ext = intbbox

    if getattr(self, "align_interiors")
        g = _Grid(self.rows, self.cols, intbbox,
            getattr(self,"cellpadding"), getattr(self,"cellspacing"))

        for i = 1:self.rows
            for j = 1:self.cols
                obj = self.content[i,j]
                subregion = cellbb(g, i, j)
                ext += exterior(obj, device, subregion)
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
end

function limits(self::Plot)
    return _limits(limits(self.content), getattr(self,"gutter"),
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
    proj = PlotGeometry(xrange(lmts)..., yrange(lmts)..., region, xlog, ylog)
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
    xr = xrange(limits)
    yr = yrange(limits)
    proj = PlotGeometry(xr..., yr..., region, xlog, ylog)
    context = PlotContext(device, region, limits, proj, xlog, ylog)
    render(frame, context)
end

_frame_bbox(obj, device, region, limits) =
    _frame_bbox(obj, device, region, limits, (0,1,1,0))
function _frame_bbox(obj, device, region, limits, labelticks)
    frame = Frame(labelticks)
    xlog = getattr(obj, "xlog")
    ylog = getattr(obj, "ylog")
    xr = xrange(limits)
    yr = yrange(limits)
    proj = PlotGeometry(xr..., yr..., region, xlog, ylog)
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
    return minfinite(a[1],b[1]), maxfinite(a[2],b[2])
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

function _limits_uniform(self)
    lmts = BoundingBox()
    for i in 1:self.nrows, j=1:self.ncols
        obj = self.content[i,j]
        lmts += limits(obj)
    end
    return lmts
end

function _limits_nonuniform(self::FramedArray, i, j)
    lx = nothing
    for k in 1:self.nrows
        l = limits(self.content[k,j])
        lx = _range_union(xrange(l), lx)
    end
    ly = nothing
    for k in 1:self.ncols
        l = limits(self.content[i,k])
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
        text(device, x, y, getattr(self,"xlabel"); halign="center", valign="top")
    end
    if !is(getattr(self,"ylabel"),nothing)
        x = xmin(bb) - labeloffset
        y = center(int_bbox).y
        text(device, x, y, getattr(self,"ylabel"); angle=90., halign="center", valign="bottom")
    end
    restore_state(device)
end

function add(self::FramedArray, args::PlotComponent...)
    for i in 1:self.nrows, j=1:self.ncols
        obj = self.content[i,j]
        add(obj, args...)
    end
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
        offset = _size_relative(getattr(self, "title_offset"), int_bbox)
        ext_bbox = exterior(self, device, int_bbox)
        x = center(int_bbox).x
        y = ymax(ext_bbox) + offset
        style = Dict()
        for (k,v) in getattr(self, "title_style")
            style[k] = v
        end
        style[:fontsize] = _fontsize_relative(
            getattr(self,:title_style)[:fontsize], int_bbox, boundingbox(device))
        save_state(device)
        for (key,val) in style
            set(device, key, val)
        end
        text(device, x, y, getattr(self,:title); halign="center", valign="bottom")
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

boundingbox(device::Renderer) = BoundingBox(0, width(device), 0, height(device))

page_compose(self::PlotContainer, device::GraphicsDevice) =
    page_compose(self, CairoRenderer(device))

function page_compose(self::PlotContainer, device::Renderer)
    bb = boundingbox(device)
    for (key,val) in config_options("defaults")
        set(device, key, val)
    end
    bb *= 1 - getattr(self, "page_margin")
    save(device.ctx)
    Cairo.scale(device.ctx,1.0,-1.0)
    Cairo.translate(device.ctx,0.0,-height(device))
    compose(self, device, bb)
    restore(device.ctx)
end

# function x11(self::PlotContainer, args...)
#     println("sorry, not implemented yet")
#     return
#     opts = args2dict(args...)
#     width = has(opts,"width") ? opts["width"] : config_value("window","width")
#     height = has(opts,"height") ? opts["height"] : config_value("window","height")
#     reuse_window = isinteractive() && config_value("window","reuse")
#     device = ScreenRenderer(reuse_window, width, height)
#     page_compose(self, device)
# end

function write_eps(self::PlotContainer, filename::String, width::String, height::String)
    write_eps(self, filename, _str_size_to_pts(width), _str_size_to_pts(height))
end

function write_eps(self::PlotContainer, filename::String, width::Real, height::Real)
    surface = CairoEPSSurface(filename, width, height)
    r = CairoRenderer(surface)
    page_compose(self, r)
    show_page(r.ctx)
    finish(surface)
end

function write_pdf(self, filename::String, width::String, height::String)
    write_pdf(self, filename, _str_size_to_pts(width), _str_size_to_pts(height))
end

function write_pdf(self::PlotContainer, filename::String, width::Real, height::Real)
    surface = CairoPDFSurface(filename, width, height)
    r = CairoRenderer(surface)
    page_compose(self, r)
    show_page(r.ctx)
    finish(surface)
end

function write_pdf{T<:PlotContainer}(plots::Vector{T}, filename::String, width::Real, height::Real)
    surface = CairoPDFSurface(filename, width, height)
    r = CairoRenderer(surface)
    for plt in plots
        page_compose(plt, r)
        show_page(r.ctx)
    end
    finish(surface)
end

function write_png(self::PlotContainer, filename::String, width::Int, height::Int)
    surface = CairoRGBSurface(width, height)
    r = CairoRenderer(surface)
    set_source_rgb(r.ctx, 1.,1.,1.)
    paint(r.ctx)
    set_source_rgb(r.ctx, 0.,0.,0.)
    page_compose(self, r)
    write_to_png(surface, filename)
    finish(surface)
end

function file(self::PlotContainer, filename::String, args...; kvs...)
    extn = filename[end-2:end]
    opts = args2dict(args...; kvs...)
    if extn == "eps"
        width = get(opts,:width,config_value("eps","width"))
        height = get(opts,:height,config_value("eps","height"))
        write_eps(self, filename, width, height)
    elseif extn == "pdf"
        width = get(opts,:width,config_value("pdf","width"))
        height = get(opts,:height,config_value("pdf","height"))
        write_pdf(self, filename, width, height)
    elseif extn == "png"
        width = get(opts,:width,config_value("window","width"))
        height = get(opts,:height,config_value("window","height"))
        write_png(self, filename, width, height)
    else
        error("I can't export .$extn, sorry.")
    end
end

function file{T<:PlotContainer}(plots::Vector{T}, filename::String, args...; kvs...)
    extn = filename[end-2:end]
    opts = args2dict(args...; kvs...)
    if extn == "pdf"
        width = get(opts,:width,config_value("pdf","width"))
        height = get(opts,:height,config_value("pdf","height"))
        write_pdf(plots, filename, width, height)
    else
        error("I can't export multiple pages to .$extn, sorry.")
    end
end

function svg(self::PlotContainer, args...; kvs...)
    opts = args2dict(args...; kvs...)
    width = get(opts,:width,config_value("window","width"))
    height = get(opts,:height,config_value("window","height"))
    stream = IOBuffer()

    surface = CairoSVGSurface(stream, width, height)
    r = CairoRenderer(surface)

    page_compose(self, r)
    show_page(r.ctx)
    finish(surface)

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

_kw_rename(::LineComponent) = [
    :color => :linecolor,
    :kind => :linekind,
    :width => :linewidth,
    # deprecated
    :type => :linekind,
    :linetype => :linekind,
]

function make_key(self::LineComponent, bbox::BoundingBox)
    y = center(bbox).y
    p = Point(xmin(bbox), y)
    q = Point(xmax(bbox), y)
    return LineObject(p, q, getattr(self,"style"))
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

function limits(self::Curve)
    return BoundingBox(minfinite(self.x), maxfinite(self.x), minfinite(self.y), maxfinite(self.y))
end

function make(self::Curve, context)
    objs = {}
    x, y = project(context.geom, self.x, self.y)
    push!(objs, PathObject(x, y))
    objs
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
        l = { Point(xr[1], self.intercept[2]),
              Point(xr[2], self.intercept[2]) }
    else
        l = { Point(xr[1], _y(self, xr[1])),
              Point(xr[2], _y(self, xr[2])),
              Point(_x(self, yr[1]), yr[1]),
              Point(_x(self, yr[2]), yr[2]) }
    end
    m = {}
    for el in l
        if isinside(context.data_bbox, el)
            push!(m, el)
        end
    end
    #sort!(m)
    objs = {}
    if length(m) > 1
        a = project(context.geom, m[1])
        b = project(context.geom, m[end])
        push!(objs, LineObject(a, b))
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

function limits(self::Histogram)
    if getattr(self, "drop_to_zero")
        p = Point(minfinite(self.edges), minfinite(0, minfinite(self.values)))
    else
        p = Point(minfinite(self.edges), minfinite(self.values))
    end
    q = Point(maxfinite(self.edges), maxfinite(self.values))
    return BoundingBox(p, q)
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
    [ PathObject(u, v) ]
end

type LineX <: LineComponent
    attr::PlotAttributes
    x

    function LineX(x, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.x = x
        self
    end
end

function limits(self::LineX)
    return BoundingBox(self.x, self.x, NaN, NaN)
end

function make(self::LineX, context::PlotContext)
    yr = yrange(context.data_bbox)
    a = project(context.geom, Point(self.x, yr[1]))
    b = project(context.geom, Point(self.x, yr[2]))
    [ LineObject(a, b) ]
end

type LineY <: LineComponent
    attr::PlotAttributes
    y

    function LineY(y, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.y = y
        self
    end
end

function limits(self::LineY)
    return BoundingBox(NaN, NaN, self.y, self.y)
end

function make(self::LineY, context::PlotContext)
    xr = xrange(context.data_bbox)
    a = project(context.geom, Point(xr[1], self.y))
    b = project(context.geom, Point(xr[2], self.y))
    [ LineObject(a, b) ]
end

type BoxLabel <: PlotComponent
    attr::PlotAttributes
    obj
    str::String
    side
    offset

    function BoxLabel(obj, str::String, side, offset, args...; kvs...)
        @assert !is(str,nothing)
        self = new(Dict(), obj, str, side, offset)
        kw_init(self, args...; kvs...)
        self
    end
end

_kw_rename(::BoxLabel) = [
    :face => :fontface,
    :size => :fontsize,
]

function make(self::BoxLabel, context)
    bb = boundingbox(self.obj, context)
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
    t = TextObject(pos, self.str, getattr(self, "style");
                   angle=angle*180./pi, valign=valign)
    [ t ]
end

# LabelComponent --------------------------------------------------------------

abstract LabelComponent <: PlotComponent

_kw_rename(::LabelComponent) = [
    :face      => :fontface,
    :size      => :fontsize,
    :angle     => :textangle,
    :halign    => :texthalign,
    :valign    => :textvalign,
]

#function limits(self::LabelComponent)
#    return BoundingBox()
#end

type DataLabel <: LabelComponent
    attr::PlotAttributes
    pos::Point
    str::String

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

    t = TextObject(xy, self.str, getattr(self, "style"); angle=textangle,halign=texthalign,valign=textvalign)
    [ t ]
end

type PlotLabel <: LabelComponent
    attr::PlotAttributes
    pos::Point
    str::String

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

    t = TextObject(pos, self.str, getattr(self, "style"); angle=textangle,halign=texthalign,valign=textvalign)
    [ t ]
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
#    l = LabelsObject(zip(x,y), self.labels, self.kw_style)
#    add(self, l)
#end

# FillComponent -------------------------------------------------------------

abstract FillComponent <: PlotComponent

function make_key(self::FillComponent, bbox::BoundingBox)
    p = lowerleft(bbox)
    q = upperright(bbox)
    return BoxObject(p, q, getattr(self,"style"))
end

kw_defaults(::FillComponent) = [
    :color => config_value("FillComponent","fillcolor"),
    :fillkind => config_value("FillComponent","fillkind"),
]

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

function limits(self::FillAbove)
    return BoundingBox(minfinite(self.x), maxfinite(self.x), minfinite(self.y), maxfinite(self.y))
end

function make(self::FillAbove, context)
    coords = map((a,b)->project(context.geom,Point(a,b)), self.x, self.y)
    max_y = ymax(context.data_bbox)
    push!(coords, project(context.geom, Point(self.x[end], max_y)))
    push!(coords, project(context.geom, Point(self.x[1], max_y)))
    [ PolygonObject(coords) ]
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

function limits(self::FillBelow)
    return BoundingBox(minfinite(self.x), maxfinite(self.x), minfinite(self.y), maxfinite(self.y))
end

function make(self::FillBelow, context)
    coords = map((a,b)->project(context.geom,Point(a,b)), self.x, self.y)
    min_y = ymin(context.data_bbox)
    push!(coords, project(context.geom, Point(self.x[end], min_y)))
    push!(coords, project(context.geom, Point(self.x[1], min_y)))
    [ PolygonObject(coords) ]
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

function limits(self::FillBetween)
    min_x = minfinite(minfinite(self.x1), minfinite(self.x2))
    max_x = maxfinite(maxfinite(self.x1), maxfinite(self.x2))
    min_y = minfinite(minfinite(self.y1), minfinite(self.y2))
    max_y = maxfinite(maxfinite(self.y1), maxfinite(self.y2))
    return BoundingBox(min_x, max_x, min_y, max_y)
end

function make(self::FillBetween, context)
    x = [self.x1, reverse(self.x2)]
    y = [self.y1, reverse(self.y2)]
    coords = map((a,b) -> project(context.geom,Point(a,b)), x, y)
    [ PolygonObject(coords) ]
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

function limits(self::Image)
    return BoundingBox(self.x, self.x+self.w, self.y, self.y+self.h)
end

function make(self::Image, context)
    a = project(context.geom, Point(self.x, self.y))
    b = project(context.geom, Point(self.x+self.w, self.y+self.h))
    bbox = BoundingBox(a, b)
    [ ImageObject(self.img, bbox) ]
end

# SymbolDataComponent --------------------------------------------------------

abstract SymbolDataComponent <: PlotComponent

_kw_rename(::SymbolDataComponent) = [
    :kind => :symbolkind,
    :size => :symbolsize,
    # deprecated
    :type => :symbolkind,
    :symboltype => :symbolkind,
]

function make_key(self::SymbolDataComponent, bbox::BoundingBox)
    pos = center(bbox)
    return SymbolObject(pos, getattr(self,"style"))
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

kw_defaults(::SymbolDataComponent) = [
    :symbolkind => config_value("Points","symbolkind"),
    :symbolsize => config_value("Points","symbolsize"),
]

function limits(self::SymbolDataComponent)
    return BoundingBox(minfinite(self.x), maxfinite(self.x), minfinite(self.y), maxfinite(self.y))
end

function make(self::SymbolDataComponent, context::PlotContext)
    x, y = project(context.geom, self.x, self.y)
    [ SymbolsObject(x, y) ]
end

function Point(x::Real, y::Real, args...)
    return Points([x], [y], args...)
end

type ColoredPoints <: SymbolDataComponent
    attr::PlotAttributes
    x
    y
    c

    function ColoredPoints(x, y, c, args...; kvs...)
        self = new(Dict())
        iniattr(self)
        kw_init(self, args...; kvs...)
        self.x = x
        self.y = y
        self.c = c
        self
    end
end

kw_defaults(::ColoredPoints) = [
    :symbolkind => config_value("Points","symbolkind"),
    :symbolsize => config_value("Points","symbolsize"),
]

function limits(self::ColoredPoints)
    return BoundingBox(minfinite(self.x), maxfinite(self.x), minfinite(self.y), maxfinite(self.y))
end

function make(self::ColoredPoints, context::PlotContext)
    x, y = project(context.geom, self.x, self.y)
    [ ColoredSymbolsObject(x, y, self.c) ]
end

function ColoredPoint(x::Real, y::Real, args...)
    return ColoredPoints([x], [y], args...)
end

# PlotComponent ---------------------------------------------------------------

function show(io::IO, self::PlotComponent)
    print(io, typeof(self), "(...)")
end

function limits(self::PlotComponent)
    return BoundingBox()
end

function make_key(self::PlotComponent, bbox::BoundingBox)
end

function boundingbox(self::PlotComponent, context::PlotContext)
    objs = make(self, context)
    bb = BoundingBox()
    for obj in objs
        x = boundingbox(obj, context)
        bb += x
    end
    return bb
end

function render(self::PlotComponent, context)
    objs = make(self, context)
    push_style(context, getattr(self,"style"))
    for obj in objs
        render(obj, context)
    end
    pop_style(context)
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

hasattr(self::HasAttr, name::String) = hasattr(self, symbol(name))
getattr(self::HasAttr, name::String) = getattr(self, symbol(name))
getattr(self::HasAttr, name::String, notfound) = getattr(self, symbol(name), notfound)
setattr(self::HasAttr, name::String, value) = setattr(self, symbol(name), value)
setattr(self::HasAttr; kvs...) = (for (k,v) in kvs; setattr(self, k, v); end)

function iniattr(self::HasAttr, args...; kvs...)
    types = {typeof(self)}
    while super(types[end]) != Any
        push!(types, super(types[end]))
    end
    for t in reverse(types)
        name = string(t)
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
_kw_rename(x) = (Symbol=>Symbol)[]

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

end # module
