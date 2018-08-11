
struct PaintContext
    device
    yardstick::Float64
    min_fontsize::Float64
end

function push_style(context::PaintContext, style)
    save_state(context.device)
    if style !== nothing
        for (key, value) in style
            if key == :fontsize
                value = max(value*context.yardstick, context.min_fontsize)
            elseif key == :linewidth
                value *= 0.1*context.yardstick
            elseif key == :symbolsize
                value *= context.yardstick
            end
            set(context.device, key, value)
        end
    end
end

function pop_style(context::PaintContext)
    restore_state(context.device)
end

abstract type AbstractPainter end

struct GroupPainter <: AbstractPainter
    style::Dict{Symbol,Any}
    children::Array{AbstractPainter,1}
end

GroupPainter(d::Dict{Symbol,Any}, args::AbstractPainter...) =
    GroupPainter(d, AbstractPainter[arg for arg in args])

function GroupPainter(args::AbstractPainter...; kvs...)
    self = GroupPainter(Dict{Symbol,Any}(), Any[args...])
    for (k,v) in kvs
        self.style[k] = v
    end
    self
end

Base.isempty(g::GroupPainter) = isempty(g.children)
Base.push!(g::GroupPainter, p::AbstractPainter...) = push!(g.children, p...)

function boundingbox(g::GroupPainter, context::PaintContext)
    push_style(context, g.style)
    bbox = BoundingBox()
    for child in g.children
        bbox += boundingbox(child, context)
    end
    pop_style(context)
    bbox
end

function paint(g::GroupPainter, context::PaintContext)
    push_style(context, g.style)
    for child in g.children
        paint(child, context)
    end
    pop_style(context)
end

struct LinePainter <: AbstractPainter
    p::Point
    q::Point
end

function boundingbox(self::LinePainter, context::PaintContext)
    BoundingBox(self.p, self.q)
end

function paint(self::LinePainter, context::PaintContext)
    line(context.device, self.p.x, self.p.y, self.q.x, self.q.y)
end

struct LabelsPainter <: AbstractPainter
    points::Vector{Point}
    labels::Vector
    angle::Float64
    halign::String
    valign::String
end

function LabelsPainter(points, labels; angle=0., halign="center", valign="center")
    LabelsPainter(points, labels, angle, halign, valign)
end

__halign_offset = Dict( "right"=>Vec2(-1,0), "center"=>Vec2(-.5,.5), "left"=>Vec2(0,1) )
__valign_offset = Dict( "top"=>Vec2(-1,0), "center"=>Vec2(-.5,.5), "bottom"=>Vec2(0,1) )

function boundingbox(self::LabelsPainter, context::PaintContext)
    bb = BoundingBox()
    angle = self.angle * pi/180.

    height = textheight(context.device, self.labels[1])
    ho = __halign_offset[self.halign]
    vo = __valign_offset[self.valign]

    for i = 1:length(self.labels)
        pos = self.points[i]
        width = textwidth(context.device, self.labels[i])

        p = Point(pos.x + width * ho.x, pos.y + height * vo.x)
        q = Point(pos.x + width * ho.y, pos.y + height * vo.y)

        bb_label = BoundingBox(p, q)
        if angle != 0
            bb_label = rotate(bb_label, angle, pos)
        end
        bb += bb_label
    end

    return bb
end

function paint(self::LabelsPainter, context::PaintContext)
    for i in 1:length(self.labels)
        p = self.points[i]
        textdraw(context.device, p.x, p.y, self.labels[i];
                 angle=self.angle, halign=self.halign, valign=self.valign)
    end
end

struct CombPainter <: AbstractPainter
    points::Vector{Point}
    dp
end

function boundingbox(self::CombPainter, context::PaintContext)
    return BoundingBox(self.points...)
end

function paint(self::CombPainter, context::PaintContext)
    for p in self.points
        move_to(context.device, p.x, p.y)
        rel_line_to(context.device, self.dp.x, self.dp.y)
    end
    stroke(context.device)
end

struct SymbolPainter <: AbstractPainter
    pos::Point
end

function boundingbox(self::SymbolPainter, context::PaintContext)
    symbolsize = get(context.device, "symbolsize")

    x = self.pos.x
    y = self.pos.y
    d = 0.5*symbolsize
    return BoundingBox(x-d, x+d, y-d, y+d)
end

function paint(self::SymbolPainter, context::PaintContext)
    symbols(context.device, [self.pos.x], [self.pos.y])
end

struct SymbolsPainter <: AbstractPainter
    x
    y
end

function boundingbox(self::SymbolsPainter, context::PaintContext)
    xmin = minimum(self.x)
    xmax = maximum(self.x)
    ymin = minimum(self.y)
    ymax = maximum(self.y)
    return BoundingBox(xmin, xmax, ymin, ymax)
end

function paint(self::SymbolsPainter, context::PaintContext)
    symbols(context.device, self.x, self.y)
end

struct ColoredSymbolsPainter <: AbstractPainter
    x::AbstractVecOrMat
    y::AbstractVecOrMat
    s::AbstractVecOrMat
    c::AbstractVecOrMat
end

function boundingbox(self::ColoredSymbolsPainter, context::PaintContext)
    xmin,xmax = extrema(self.x)
    ymin,ymax = extrema(self.y)
    return BoundingBox(xmin, xmax, ymin, ymax)
end

function paint(self::ColoredSymbolsPainter, context::PaintContext)
    fullname = get(context.device.state, :symbolkind, "circle")
    splitname = split(fullname)
    name = pop!(splitname)
    filled = "solid" in splitname || "filled" in splitname

    default_symbol_func = symbol_funcs["circle"]
    symbol_func = get(symbol_funcs, name, default_symbol_func)

    device = context.device.ctx
    save(device)
    set_dash(device, Float64[])
    new_path(device)
    for (x,y,s,c) in zip(self.x, self.y, self.s, self.c)
        set_color(device, c)
        symbol_func(device, x, y, s*context.yardstick)
        if filled
            fill_preserve(device)
        end
        stroke(device)
    end
    restore(device)
end

struct TextPainter <: AbstractPainter
    pos::Point
    str::String
    angle::Float64
    halign::String
    valign::String
end

function TextPainter(pos, str; angle=0., halign="center", valign="center")
    TextPainter(pos, str, angle, halign, valign)
end

function boundingbox(self::TextPainter, context::PaintContext)
    angle = self.angle * pi/180.
    width = textwidth(context.device, self.str)
    height = textheight(context.device, self.str)

    hvec = width * __halign_offset[self.halign]
    vvec = height * __valign_offset[self.valign]

    bb = BoundingBox(self.pos.x + hvec.x, self.pos.x + hvec.y,
                     self.pos.y + vvec.x, self.pos.y + vvec.y)
    bb = rotate(bb, angle, self.pos)
    return bb
end

function paint(self::TextPainter, context::PaintContext)
    textdraw(context.device, self.pos.x, self.pos.y, self.str;
             angle=self.angle, halign=self.halign, valign=self.valign)
end

struct PathPainter <: AbstractPainter
    x::AbstractArray
    y::AbstractArray
end

function boundingbox(self::PathPainter, context::PaintContext)
    xmin = minimum(self.x)
    xmax = maximum(self.x)
    ymin = minimum(self.y)
    ymax = maximum(self.y)
    return BoundingBox(xmin, xmax, ymin, ymax)
end

function paint(self::PathPainter, context::PaintContext)
    curve(context.device, self.x, self.y)
end

struct PolygonPainter <: AbstractPainter
    points::Vector{Point}
end

function boundingbox(self::PolygonPainter, context::PaintContext)
    return BoundingBox(self.points...)
end

function paint(self::PolygonPainter, context::PaintContext)
    polygon(context.device, self.points)
end

struct BoxPainter <: AbstractPainter
    p::Point
    q::Point
end

function boundingbox(self::BoxPainter, context::PaintContext)
    return BoundingBox(self.p, self.q)
end

function paint(self::BoxPainter, context::PaintContext)
    linecolor = get(context.device, :linecolor)
    linecolor != nothing && set_color(context.device.ctx, linecolor)
    fillcolor = get(context.device, :fillcolor)
    fillcolor != nothing && set_color(context.device.ctx, fillcolor)
    rectangle(context.device, BoundingBox(self.p, self.q), true)
    if linecolor != nothing
        set_color(context.device.ctx, linecolor)
        rectangle(context.device, BoundingBox(self.p, self.q), false)
    end
end

struct ImagePainter <: AbstractPainter
    img
    bbox
end

function boundingbox(self::ImagePainter, context::PaintContext)
    return self.bbox
end

function paint(self::ImagePainter, context::PaintContext)
    ll = lowerleft(self.bbox)
    w = width(self.bbox)
    h = height(self.bbox)
    image(context.device, self.img, ll.x, ll.y, w, h)
end

struct StrutPainter <: AbstractPainter
    bbox::BoundingBox
end

boundingbox(self::StrutPainter, context::PaintContext) = self.bbox

function paint(self::StrutPainter, context::PaintContext)
    # do nothing -- just for sizing
end
