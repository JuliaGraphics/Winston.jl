
export
    issue008,
    issue010,
    issue100,
    issue143,
    issue146a,
    issue146b,
    issue176

function issue008()
    large = [i^4 + 1e12 for i in 1:10^3]
    small = [1:10^3;]
    plot(small,large)
end

function issue010()
    p = plot(abs.(sin.(0:.1:10)))
    setattr(p, "ylog", true)
    setattr(p, "yrange", (5e-6,0.2))
    p
end

function issue100()
    x = range(0, stop=6pi, length=100)
    y = sin.(x)
    stem(x, y, "b;")
end

function issue143()
    p = plot(1:10, yrange=(10,0))
    setattr(p.y2, draw_ticklabels=true)
    p
end

issue146a() = plot(sin, 0, 2pi)
issue146b() = plot(sin, cos, xrange=[0,2pi], yrange=[-2,2])

function issue176()
    t = Table(2,2)
    z = reshape(1:100, 10, 10)
    t[1,1] = imagesc((1,10), (1,10), z)
    t[1,2] = imagesc((1,10), (10,1), z)
    t[2,1] = imagesc((10,1), (1,10), z)
    t[2,2] = imagesc((10,1), (10,1), z)
    t
end
