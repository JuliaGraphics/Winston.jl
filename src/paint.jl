# =============================================================================
#
# RenderObjects
#
# =============================================================================

abstract RenderObject
typealias RenderStyle Dict{String,Union(Integer,FloatingPoint,String)}

function kw_init(self::RenderObject, args...)
    for (k,v) in kw_defaults(self)
        self.style[k] = v
    end
    for (key, value) in args2dict(args...)
        self.style[key] = value
    end
end

type LineObject <: RenderObject
    style::RenderStyle
    p::Point
    q::Point

    function LineObject(p, q, args...)
        self = new(RenderStyle(), p, q)
        kw_init(self, args...)
        self
    end
end

_kw_rename(::LineObject) = [
    "width"     => "linewidth",
    "type"      => "linetype",
]

function boundingbox(self::LineObject, context)
    BoundingBox(self.p, self.q)
end

function draw(self::LineObject, context)
    line(context.draw, self.p.x, self.p.y, self.q.x, self.q.y)
end

type LabelsObject <: RenderObject
    style::RenderStyle
    points::Vector{Point}
    labels::Vector

    function LabelsObject(points, labels, args...)
        self = new(RenderStyle(), points, labels)
        kw_init(self, args...)
        self
    end
end

kw_defaults(::LabelsObject) = [
    "textangle"     => 0,
    "texthalign"    => "center",
    "textvalign"    => "center",
]

_kw_rename(::LabelsObject) = [
    "face"      => "fontface",
    "size"      => "fontsize",
    "angle"     => "textangle",
    "halign"    => "texthalign",
    "valign"    => "textvalign",
]

__halign_offset = [ "right"=>Vec2(-1,0), "center"=>Vec2(-.5,.5), "left"=>Vec2(0,1) ]
__valign_offset = [ "top"=>Vec2(-1,0), "center"=>Vec2(-.5,.5), "bottom"=>Vec2(0,1) ]

function boundingbox(self::LabelsObject, context)
    bb = BoundingBox()
    push_style(context, self.style)

    angle = get(context.draw, "textangle") * pi/180.
    halign = get(context.draw, "texthalign")
    valign = get(context.draw, "textvalign")

    height = textheight(context.draw, self.labels[1])
    ho = __halign_offset[halign]
    vo = __valign_offset[valign]

    for i = 1:length(self.labels)
        pos = self.points[i]
        width = textwidth(context.draw, self.labels[i])

        p = Point(pos.x + width * ho.x, pos.y + height * vo.x)
        q = Point(pos.x + width * ho.y, pos.y + height * vo.y)

        bb_label = BoundingBox(p, q)
        if angle != 0
            bb_label = rotate(bb_label, angle, pos)
        end
        bb += bb_label
    end

    pop_style(context)
    return bb
end

function draw(self::LabelsObject, context)
    for i in 1:length(self.labels)
        p = self.points[i]
        text(context.draw, p.x, p.y, self.labels[i])
    end
end

type CombObject <: RenderObject
    style::RenderStyle
    points::Vector{Point}
    dp

    function CombObject(points, dp, args...)
        self = new(RenderStyle())
        kw_init(self, args...)
        self.points = points
        self.dp = dp
        self
    end
end

function boundingbox(self::CombObject, context::PlotContext)
    return BoundingBox(self.points...)
end

function draw(self::CombObject, context::PlotContext)
    for p in self.points
        move_to(context.draw, p.x, p.y)
        rel_line_to(context.draw, self.dp.x, self.dp.y)
    end
    stroke(context.draw)
end

type SymbolObject <: RenderObject
    style::RenderStyle
    pos::Point

    function SymbolObject(pos, args...)
        self = new(RenderStyle(), pos)
        kw_init(self, args...)
        self
    end
end

_kw_rename(::SymbolObject) = [
    "type" => "symboltype",
    "size" => "symbolsize",
]

function boundingbox(self::SymbolObject, context)
    push_style(context, self.style)
    symbolsize = get(context.draw, "symbolsize")
    pop_style(context)

    x = self.pos.x
    y = self.pos.y
    d = 0.5*symbolsize
    return BoundingBox(x-d, x+d, y-d, y+d)
end

function draw(self::SymbolObject, context)
    symbol(context.draw, self.pos.x, self.pos.y)
end

type SymbolsObject <: RenderObject
    style::RenderStyle
    x
    y

    function SymbolsObject(x, y, args...)
        self = new(RenderStyle())
        kw_init(self, args...)
        self.x = x
        self.y = y
        self
    end
end

_kw_rename(::SymbolsObject) = [
    "type" => "symboltype",
    "size" => "symbolsize",
]

function boundingbox(self::SymbolsObject, context::PlotContext)
    xmin = min(self.x)
    xmax = max(self.x)
    ymin = min(self.y)
    ymax = max(self.y)
    return BoundingBox(xmin, xmax, ymin, ymax)
end

function draw(self::SymbolsObject, context::PlotContext)
    symbols(context.draw, self.x, self.y)
end

type TextObject <: RenderObject
    style::RenderStyle
    pos::Point
    str::String

    function TextObject(pos, str, args...)
        self = new(RenderStyle(), pos, str)
        kw_init(self, args...)
        self
    end
end

kw_defaults(::TextObject) = [
    "textangle"     => 0,
    "texthalign"    => "center",
    "textvalign"    => "center",
]

_kw_rename(::TextObject) = [
    "face"      => "fontface",
    "size"      => "fontsize",
    "angle"     => "textangle",
    "halign"    => "texthalign",
    "valign"    => "textvalign",
]

function boundingbox(self::TextObject, context::PlotContext)
    push_style(context, self.style)
    angle = get(context.draw, "textangle") * pi/180.
    halign = get(context.draw, "texthalign")
    valign = get(context.draw, "textvalign")
    width = textwidth(context.draw, self.str)
    height = textheight(context.draw, self.str)
    pop_style(context)

    hvec = width * __halign_offset[halign]
    vvec = height * __valign_offset[valign]

    bb = BoundingBox(self.pos.x + hvec.x, self.pos.x + hvec.y,
                     self.pos.y + vvec.x, self.pos.y + vvec.y)
    bb = rotate(bb, angle, self.pos)
    return bb
end

function draw(self::TextObject, context::PlotContext)
    text(context.draw, self.pos.x, self.pos.y, self.str)
end

function LineTextObject(p::Point, q::Point, str, offset, args...)
    #kw_init(self, args...)
    #self.str = str

    midpoint = 0.5*(p + q)
    direction = q - p
    direction /= norm(direction)
    angle = atan2(direction.y, direction.x)
    direction = rotate(direction, pi/2)
    pos = midpoint + offset*direction

    kw = [ "textangle" => angle * 180./pi,
           "texthalign" => "center" ]
    if offset > 0
        kw["textvalign"] = "bottom"
    else
        kw["textvalign"] = "top"
    end
    TextObject(pos, str, args..., kw)
end

type PathObject <: RenderObject
    style::RenderStyle
    x::Vector{Float64}
    y::Vector{Float64}

    function PathObject(x, y, args...)
        self = new(RenderStyle())
        kw_init(self, args...)
        self.x = x
        self.y = y
        self
    end
end

_kw_rename(::PathObject) = [
    "width"     => "linewidth",
    "type"      => "linetype",
]

function boundingbox(self::PathObject, context)
    xmin = min(self.x)
    xmax = max(self.x)
    ymin = min(self.y)
    ymax = max(self.y)
    return BoundingBox(xmin, xmax, ymin, ymax)
end

function draw(self::PathObject, context)
    curve(context.draw, self.x, self.y)
end

type PolygonObject <: RenderObject
    style::RenderStyle
    points::Vector{Point}

    function PolygonObject(points, args...)
        self = new(RenderStyle())
        kw_init(self, args...)
        self.points = points
        self
    end
end

_kw_rename(::PolygonObject) = [
    "width"     => "linewidth",
    "type"      => "linetype",
]

function boundingbox(self::PolygonObject, context)
    return BoundingBox(self.points...)
end

function draw(self::PolygonObject, context)
    polygon(context.draw, self.points)
end

type ImageObject <: RenderObject
    style::RenderStyle
    img
    bbox

    function ImageObject(img, bbox, args...)
        self = new(RenderStyle(), img, bbox)
        kw_init(self, args...)
        self
    end
end

function boundingbox(self::ImageObject, context)
    return self.bbox
end

function draw(self::ImageObject, context)
    ll = lowerleft(self.bbox)
    w = width(self.bbox)
    h = height(self.bbox)
    if context.geom.yflipped
        image(context.draw, self.img, ll.x, ll.y+h, w, -h)
    else
        image(context.draw, self.img, ll.x, ll.y, w, h)
    end
end

# defaults

#function boundingbox(self::RenderObject, context)
#    return BoundingBox()
#end

function render(self::RenderObject, context)
    push_style(context, self.style)
    draw(self, context)
    pop_style(context)
end

