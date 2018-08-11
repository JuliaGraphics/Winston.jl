
#
#  y1 +------+
#     |      |
#     |      |
#     |      |
#  y0 +------+
#     x0     x1
#
struct Rectangle
    x0::Float64
    x1::Float64
    y0::Float64
    y1::Float64
end

Rectangle() = Rectangle(NaN, NaN, NaN, NaN)
Rectangle(lowerleft::Point, upperright::Point) =
    Rectangle(lowerleft.x, lowerleft.y, upperright.x, upperright.y)
function Rectangle(bb::BoundingBox, xflipped::Bool, yflipped::Bool)
    p = xflipped ? Point(bb.xmax, bb.xmin) : Point(bb.xmin, bb.xmax)
    q = yflipped ? Point(bb.ymax, bb.ymin) : Point(bb.ymin, bb.ymax)
    Rectangle(p, q)
end

BoundingBox(r::Rectangle) = BoundingBox(NaNMath.min(r.x0,r.x1), NaNMath.max(r.x0,r.x1),
                                        NaNMath.min(r.y0,r.y1), NaNMath.max(r.y0,r.y1))

isincomplete(bb::BoundingBox) = isnan(bb.xmin) || isnan(bb.xmax) ||
                                isnan(bb.ymin) || isnan(bb.ymax)


lowerleft(r::Rectangle) = Point(r.x0, r.y0)
upperleft(r::Rectangle) = Point(r.x0, r.y1)
lowerright(r::Rectangle) = Point(r.x1, r.y0)
upperright(r::Rectangle) = Point(r.x1, r.y1)

width(r::Rectangle) = abs(r.x1 - r.x0)
height(r::Rectangle) = abs(r.y1 - r.y0)
diagonal(r::Rectangle) = hypot(r.x1 - r.x0, r.y1 - r.y0)

function deform(r::Rectangle, dl::Real, dr::Real, dt::Real, db::Real)
    Rectangle(r.x0 + dl, r.x1 + dr, r.y0 + dt, r.y1 + db)
end

# shift center by (dx,dy), keeping width & height fixed
function shift(r::Rectangle, dx::Real, dy::Real)
    Rectangle(r.x0 + dx, r.x1 + dx, r.y0 + dy, r.y1 + dy)
end

# scale width & height, keeping center fixed
function (*)(r::Rectangle, s::Real)
    dw = 0.5*(s - 1.)*(r.x1 - r.x0)
    dh = 0.5*(s - 1.)*(r.y1 - r.y0)
    deform(r, -dw, dw, -dh, dh)
end
(*)(s::Real, r::Rectangle) = r*s

# --------------------------------------------------------------------------

abstract type AbstractProjection1 end
abstract type AbstractProjection2 end

project(p::AbstractProjection2, pt::Point) = Point(project(p, pt.x, pt.y)...)

struct LinearProjection <: AbstractProjection1
    a::Float64
    b::Float64
end

project(p::LinearProjection, u) = p.a .+ p.b .* u
deproject(p::LinearProjection, x) = (x .- p.a) ./ p.b

struct LogProjection <: AbstractProjection1
    a::Float64
    b::Float64
end

project(p::LogProjection, u) = p.a .+ p.b .* log10.(u)
deproject(p::LogProjection, x) = 10.0 .^ ((x .- p.a) ./ p.b)

struct SeparableProjection2{P1<:AbstractProjection1,
                               P2<:AbstractProjection1} <: AbstractProjection2
    x::P1
    y::P2
end

project(p::SeparableProjection2, u, v) = (project(p.x,u), project(p.y,v))
deproject(p::SeparableProjection2, u, v) = (deproject(p.x,u), deproject(p.y,v))

struct PolarProjection
    x0::Float64
    y0::Float64
    sx::Float64
    sy::Float64
end

function project(p::PolarProjection, r, θ)
    x = p.x0 .+ p.sx .* r .* cos.(θ)
    y = p.y0 .+ p.sy .* r .* sin.(θ)
    x, y
end

function deproject(p::PolarProjection, x, y)
    r = hypot(x, y)
    θ = atan(y, x)
    hypot
end

function PlotGeometry(orig::Rectangle, dest::BoundingBox, xlog, ylog)
    x0 = orig.x0
    x1 = orig.x1
    y0 = orig.y0
    y1 = orig.y1

    px = LinearProjection
    py = LinearProjection
    if xlog
        x0 = log10(x0)
        x1 = log10(x1)
        px = LogProjection
    end
    if ylog
        y0 = log10(y0)
        y1 = log10(y1)
        py = LogProjection
    end

    sx = width(dest)/(x1 - x0)
    sy = height(dest)/(y1 - y0)
    tx = lowerleft(dest).x - sx * x0
    ty = lowerleft(dest).y - sy * y0

    SeparableProjection2(px(tx,sx), py(ty,sy))
end

PlotGeometry(orig::Rectangle, dest::BoundingBox) = PlotGeometry(orig, dest, false, false)
