
export
    issue008,
    issue010,
    issue143

function issue008()
    large = [i^4 + 1e12 for i in 1:10^3]
    small = [1:10^3]
    plot(small,large)
end

function issue010()
    p = plot(abs(sin(0:.1:10)))
    setattr(p, "ylog", true)
    setattr(p, "yrange", (5e-6,0.2))
    p
end

function issue143()
    p = plot(1:10, yrange=(10,0))
    setattr(p.y2, draw_ticklabels=true)
    p
end

