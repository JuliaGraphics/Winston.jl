
export
    example01,
    example02,
    example03,
    example04,
    #example05,
    example06,
    example07

function example01()
    x = range(0, stop=3pi, length=100)
    c = cos.(x)
    s = sin.(x)

    p = FramedPlot(
            title="title!",
            xlabel="\\Sigma x^2_i",
            ylabel="\\Theta_i")

    add(p, FillBetween(x, c, x, s))
    add(p, Curve(x, c, color=colorant"red"))
    add(p, Curve(x, s, color=colorant"blue"))

    p
end

function example02()
    Random.seed!(42)
    p = FramedPlot(
            aspect_ratio=1,
            xrange=(0,100),
            yrange=(0,100))

    n = 21
    x = range(0, stop=100, length=n)
    yA = 40 .+ 10*randn(n)
    yB = x + 5*randn(n)

    a = Points(x, yA, kind="circle")
    setattr(a, label="a points")

    b = Points(x, yB)
    setattr(b, label="b points")
    style(b, kind="filled circle")

    s = Slope(1, (0,0), kind="dotted")
    setattr(s, label="slope")

    l = Legend(.1, .9, Any[a,b,s])

    add(p, s, a, b, l)
    p
end

function example03()
    Random.seed!(42)
    p = FramedPlot(
            title="Title",
            xlabel="X axis",
            ylabel="Y axis")

    add(p, Histogram(Winston.hist(randn(1000))...))
    add(p, PlotLabel(.5, .5, "Histogram", color=0xcc0000))

    t1 = Table(1, 2)
    t1[1,1] = p
    t1[1,2] = p

    t2 = Table(2, 1)
    t2[1,1] = t1
    t2[2,1] = p
    t2
end

function example04()
    x = range(0., stop=2pi, length=40)
    s = sin.(x)
    c = cos.(x)

    inset = FramedPlot(title="inset")
    setattr(inset.frame, draw_ticks=false)

    add(inset, Curve(x, s, kind="dashed"))

    p = FramedPlot(aspect_ratio=1)
    setattr(p.frame, tickdir=+1, draw_spine=false)

    add(p, SymmetricErrorBarsY(x, s, 0.2*ones(length(x))))
    add(p, Points(x, s, color=colorant"red"))
    add(p, PlotInset((.6,.6), (.95,.95), inset))
    p
end

function example05()
    x = range(0., stop=2pi, length=30)
    y = sin.(x)

    p = FramedArray(2, 2,
            title="title",
            aspect_ratio=0.75,
            xlabel="x label",
            ylabel="y label",
            uniform_limits=true,
            cellspacing=1.)

    add(p, LineY(0, kind="dot"))

    add(p[1,1], Curve(x, .25*y))
    add(p[1,2], Curve(x, .50*y))
    add(p[2,1], Curve(x, .75*y))
    add(p[2,2], Curve(x, y))
    p
end

function example06()
    x = range(pi, stop=3pi, length=60)
    c = cos.(x)
    s = sin.(x)

    p = FramedPlot(aspect_ratio=1)
    setattr(p.frame1, draw_grid=true, tickdir=1)

    setattr(p.x1, label="bottom", subticks=1)
    setattr(p.y1, label="left", draw_spine=false)
    setattr(p.x2, label="top", range=(10,1000), log=true)

    setattr(p.y2, label="right", draw_ticks=false,
        ticklabels=["-1", "-1/2", "0", "1/2", "1"])

    add(p, Curve(x, c, kind="dash"))
    add(p, Curve(x, s))
    p
end

function example07()
    n = 300
    x = range(10., stop=-10., length=n)
    t = range(-1., stop=1., length=n)
    z = (3. .+ 4*cosh.(2x' .- 8t) .+ cosh.(4x' .- 64t)) ./
        (3*cosh.(x' .- 28t) + cosh.(3x' .- 36t)) .^ 2

    t = Table(2,2)
    t[1,1] = imagesc(z, (minimum(z),0.6maximum(z)))

    p = imagesc(z)
    xlim(0, 1000)
    ylim(400, 0)
    t[2,1] = p

    p = imagesc(z)
    xlim(0, 1000)
    ylim(0, 400)
    t[1,2] = p

    t
end
