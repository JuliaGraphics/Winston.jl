
type Vec2
    x::Float64
    y::Float64
end

Vec2(x::Real, y::Real) = Vec2(float64(x), float64(y))

(+)(a::Vec2, b::Vec2) = Vec2(a.x + b.x, a.y + b.y)
(-)(a::Vec2, b::Vec2) = Vec2(a.x - b.x, a.y - b.y)
(*)(p::Vec2, s::Real) = Vec2(p.x*s, p.y*s)
(/)(p::Vec2, s::Real) = Vec2(p.x/s, p.y/s)
(*)(s::Real, p::Vec2) = p*s

# rotate p around o by angle
function rotate(p::Vec2, angle::Real, o::Vec2)
    c = cos(angle)
    s = sin(angle)
    d = p - o
    Vec2(o.x + c*d.x - s*d.y, o.y + s*d.x + c*d.y)
end
rotate(p::Vec2, angle::Real) = rotate(p, angle, Vec2(0.,0.))

norm(p::Vec2) = hypot(p.x, p.y)

typealias Point Vec2

type BoundingBox
    xmin::Float64
    xmax::Float64
    ymin::Float64
    ymax::Float64
end

BoundingBox() = BoundingBox(NaN, NaN, NaN, NaN)

BoundingBox(a::Real, b::Real, c::Real, d::Real) =
    BoundingBox(float64(a), float64(b), float64(c), float64(d))

function BoundingBox(points::Point...)
    xmin, xmax, ymin, ymax = NaN, NaN, NaN, NaN
    for p in points
        xmin = min(xmin, p.x)
        xmax = max(xmax, p.x)
        ymin = min(ymin, p.y)
        ymax = max(ymax, p.y)
    end
    return BoundingBox(xmin, xmax, ymin, ymax)
end

# deprecated
function BoundingBox(args...)
    pt_min = (a, b) -> (min(a[1],b[1]), min(a[2],b[2]))
    pt_max = (a, b) -> (max(a[1],b[1]), max(a[2],b[2]))
    if length(args) > 0
        p = reduce(pt_min, args)
        q = reduce(pt_max, args)
        return BoundingBox(float(p[1]),float(q[1]),float(p[2]),float(q[2]))
    else
        return BoundingBox(NaN, NaN, NaN, NaN)
    end
end

copy(bb::BoundingBox) = BoundingBox(bb.xmin, bb.xmax, bb.ymin, bb.ymax)

width(bb::BoundingBox) = bb.xmax - bb.xmin
height(bb::BoundingBox) = bb.ymax - bb.ymin
diagonal(bb::BoundingBox) = hypot(width(bb), height(bb))
aspect_ratio(bb::BoundingBox) = height(bb)/width(bb)

xmin(bb::BoundingBox) = bb.xmin
xmax(bb::BoundingBox) = bb.xmax
ymin(bb::BoundingBox) = bb.ymin
ymax(bb::BoundingBox) = bb.ymax
xrange(bb::BoundingBox) = bb.xmin, bb.xmax
yrange(bb::BoundingBox) = bb.ymin, bb.ymax

lowerleft(bb::BoundingBox) = Point(bb.xmin, bb.ymin)
upperleft(bb::BoundingBox) = Point(bb.xmin, bb.ymax)
lowerright(bb::BoundingBox) = Point(bb.xmax, bb.ymin)
upperright(bb::BoundingBox) = Point(bb.xmax, bb.ymax)
center(bb::BoundingBox) = 0.5*Point(bb.xmin + bb.xmax, bb.ymin + bb.ymax)

function (+)(bb1::BoundingBox, bb2::BoundingBox)
    BoundingBox(min(bb1.xmin, bb2.xmin),
                max(bb1.xmax, bb2.xmax),
                min(bb1.ymin, bb2.ymin),
                max(bb1.ymax, bb2.ymax))
end

function deform(bb::BoundingBox, dt, db, dl, dr)
    BoundingBox(bb.xmin + dl, bb.xmax + dr, bb.ymin + db, bb.ymax + dt)
end

# shift center by (dx,dy), keeping width & height fixed
function shift(bb::BoundingBox, dx, dy)
    BoundingBox(bb.xmin + dx, bb.xmax + dx, bb.ymin + dy, bb.ymax + dy)
end

# scale width & height, keeping center fixed
function (*)(bb::BoundingBox, s::Real)
    dw = 0.5*(s - 1)*width(bb)
    dh = 0.5*(s - 1)*height(bb)
    deform(bb, dh, -dh, -dw, dw)
end
(*)(s::Real, bb::BoundingBox) = bb*s

function rotate(bb::BoundingBox, angle::Real, p::Point)
    a = rotate(lowerleft(bb), angle, p)
    b = rotate(lowerright(bb), angle, p)
    c = rotate(upperleft(bb), angle, p)
    d = rotate(upperright(bb), angle, p)
    BoundingBox(a, b, c, d)
end

function make_aspect_ratio(bb::BoundingBox, ratio::Real)
    if ratio < aspect_ratio(bb)
        dh = height(bb) - ratio * width(bb)
        return BoundingBox(bb.xmin, bb.xmax, bb.ymin + dh/2, bb.ymax - dh/2)
    else
        dw = width(bb) - height(bb) / ratio
        return BoundingBox(bb.xmin + dw/2, bb.xmax - dw/2, bb.ymin, bb.ymax)
    end
end

contains(bb::BoundingBox, x, y) = (bb.xmin <= x <= bb.xmax) && (bb.ymin <= y <= bb.ymax)
contains(bb::BoundingBox, p::Point) = contains(bb, p.x, p.y)
