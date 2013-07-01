
abstract Projection

type AffineTransformation
    t :: Array{Float64,1}
    m :: Array{Float64,2}
end

function AffineTransformation(x0, x1, y0, y1, dest::BoundingBox)
    sx = width(dest) / (x1 - x0)
    sy = height(dest) / (y1 - y0)
    p = lowerleft(dest)
    tx = p.x - sx * x0
    ty = p.y - sy * y0
    t = [tx, ty]
    m = diagm([sx, sy])
    AffineTransformation(t, m)
end

function project(self::AffineTransformation, x::Real, y::Real)
    #self.m*[x,y] + self.t
    u = self.t[1] + self.m[1,1] * x #+ self.m[1,2] * y
    v = self.t[2] + self.m[2,2] * y #+ self.m[2,1] * x
    u, v
end

project(proj::Projection, p::Point) = Point(project(proj, p.x, p.y)...)

function project(self::AffineTransformation, x::Vector, y::Vector)
    p = self.t[1] + self.m[1,1] * x #+ self.m[1,2] * y
    q = self.t[2] + self.m[2,2] * y #+ self.m[2,1] * x
    return p, q
end

project(self::AffineTransformation, x::AbstractArray, y::AbstractArray) =
    project(self, collect(x), collect(y))

#function compose(self::AffineTransformation, other::AffineTransformation)
#    self.t = call(other.t[1], other.t[2])
#    self.m = self.m * other.m
#end

type PlotGeometry <: Projection
    dest_bbox::BoundingBox
    xlog::Bool
    ylog::Bool
    aff::AffineTransformation
    xflipped::Bool
    yflipped::Bool

    function PlotGeometry(x0, x1, y0, y1, dest::BoundingBox, xlog, ylog)
        if xlog
            x0 = log10(x0)
            x1 = log10(x1)
        end
        if ylog
            y0 = log10(y0)
            y1 = log10(y1)
        end
        new(dest, xlog, ylog, AffineTransformation(x0,x1,y0,y1,dest), x0 > x1, y0 > y1)
    end

    PlotGeometry(x0, x1, y0, y1, dest) = PlotGeometry(x0, x1, y0, y1, dest, false, false)
end

function project(self::PlotGeometry, x, y)
    u, v = x, y
    if self.xlog
        u = log10(x)
    end
    if self.ylog
        v = log10(y)
    end
    return project(self.aff, u, v)
end

