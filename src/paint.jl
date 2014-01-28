
immutable PaintContext
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

abstract AbstractPainter

immutable GroupPainter <: AbstractPainter
    style::Dict{Symbol,Any}
    children::Array{AbstractPainter,1}
end

GroupPainter(d::Dict{Symbol,Any}, args::AbstractPainter...) =
    GroupPainter(d, AbstractPainter[arg for arg in args])

function GroupPainter(args::AbstractPainter...; kvs...)
    self = GroupPainter(Dict{Symbol,Any}(), {args...})
    for (k,v) in kvs
        self.style[k] = v
    end
    self
end

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

immutable LinePainter <: AbstractPainter
    p::Point
    q::Point
end

function boundingbox(self::LinePainter, context::PaintContext)
    BoundingBox(self.p, self.q)
end

function paint(self::LinePainter, context::PaintContext)
    line(context.device, self.p.x, self.p.y, self.q.x, self.q.y)
end

immutable LabelsPainter <: AbstractPainter
    points::Vector{Point}
    labels::Vector
    angle::Float64
    halign::ASCIIString
    valign::ASCIIString
end

function LabelsPainter(points, labels; angle=0., halign="center", valign="center")
    LabelsPainter(points, labels, angle, halign, valign)
end

__halign_offset = [ "right"=>Vec2(-1,0), "center"=>Vec2(-.5,.5), "left"=>Vec2(0,1) ]
__valign_offset = [ "top"=>Vec2(-1,0), "center"=>Vec2(-.5,.5), "bottom"=>Vec2(0,1) ]

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
        text(context.device, p.x, p.y, self.labels[i];
             angle=self.angle, halign=self.halign, valign=self.valign)
    end
end

immutable CombPainter <: AbstractPainter
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

immutable SymbolPainter <: AbstractPainter
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

immutable SymbolsPainter <: AbstractPainter
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

immutable TextPainter <: AbstractPainter
    pos::Point
    str::ByteString
    angle::Float64
    halign::ASCIIString
    valign::ASCIIString
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
    text(context.device, self.pos.x, self.pos.y, self.str;
         angle=self.angle, halign=self.halign, valign=self.valign)
end

immutable PathPainter <: AbstractPainter
    x::Vector{Float64}
    y::Vector{Float64}
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

immutable PolygonPainter <: AbstractPainter
    points::Vector{Point}
end

function boundingbox(self::PolygonPainter, context::PaintContext)
    return BoundingBox(self.points...)
end

function paint(self::PolygonPainter, context::PaintContext)
    polygon(context.device, self.points)
end

immutable ImagePainter <: AbstractPainter
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

