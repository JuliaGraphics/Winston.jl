
abstract RenderObject
typealias RenderStyle Dict{Symbol,Union(Integer,FloatingPoint,String)}

function kw_init(self::RenderObject, args...)
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
    angle::Float64
    halign::ASCIIString
    valign::ASCIIString

    function LabelsObject(points, labels, args...; angle=0., halign="center", valign="center")
        self = new(RenderStyle(), points, labels, angle, halign, valign)
        kw_init(self, args...)
        self
    end
end

__halign_offset = [ "right"=>Vec2(-1,0), "center"=>Vec2(-.5,.5), "left"=>Vec2(0,1) ]
__valign_offset = [ "top"=>Vec2(-1,0), "center"=>Vec2(-.5,.5), "bottom"=>Vec2(0,1) ]

function boundingbox(self::LabelsObject, context)
    bb = BoundingBox()
    push_style(context, self.style)

    angle = self.angle * pi/180.

    height = textheight(context.draw, self.labels[1])
    ho = __halign_offset[self.halign]
    vo = __valign_offset[self.valign]

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
        text(context.draw, p.x, p.y, self.labels[i];
             angle=self.angle, halign=self.halign, valign=self.valign)
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
    symbols(context.draw, [self.pos.x], [self.pos.y])
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

function boundingbox(self::SymbolsObject, context::PlotContext)
    xmin = minimum(self.x)
    xmax = maximum(self.x)
    ymin = minimum(self.y)
    ymax = maximum(self.y)
    return BoundingBox(xmin, xmax, ymin, ymax)
end

function draw(self::SymbolsObject, context::PlotContext)
    symbols(context.draw, self.x, self.y)
end

type TextObject <: RenderObject
    style::RenderStyle
    pos::Point
    str::String
    angle::Float64
    halign::ASCIIString
    valign::ASCIIString

    function TextObject(pos, str, args...; angle=0., halign="center", valign="center")
        self = new(RenderStyle(), pos, str, angle, halign, valign)
        kw_init(self, args...)
        self
    end
end

function boundingbox(self::TextObject, context::PlotContext)
    push_style(context, self.style)
    angle = self.angle * pi/180.
    width = textwidth(context.draw, self.str)
    height = textheight(context.draw, self.str)
    pop_style(context)

    hvec = width * __halign_offset[self.halign]
    vvec = height * __valign_offset[self.valign]

    bb = BoundingBox(self.pos.x + hvec.x, self.pos.x + hvec.y,
                     self.pos.y + vvec.x, self.pos.y + vvec.y)
    bb = rotate(bb, angle, self.pos)
    return bb
end

function draw(self::TextObject, context::PlotContext)
    text(context.draw, self.pos.x, self.pos.y, self.str;
         angle=self.angle, halign=self.halign, valign=self.valign)
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

function boundingbox(self::PathObject, context)
    xmin = minimum(self.x)
    xmax = maximum(self.x)
    ymin = minimum(self.y)
    ymax = maximum(self.y)
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
    image(context.draw, self.img, ll.x, ll.y, w, h)
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

