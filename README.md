
Winston: 2D Plotting for Julia
==============================

    require("Winston")
    using Winston

    x = [-pi:0.2:pi]
    y = sin(x)

    p = FramedPlot()
    add(p, Curve(x, y))

    file(p, "winston.eps")

Installation
------------

    julia> load("pkg.jl")

    julia> Pkg.init()
    ...

    julia> Pkg.add("Winston")

Winston is distributed with Julia, and uses Cairo as its
graphical backend:

* OS X (macports): `port install cairo pango`
* Ubuntu: `aptitude install libcairo2 libpango1.0-0`

Documentation
-------------

* [Examples](https://github.com/nolta/Winston.jl/blob/master/doc/examples.md)

Status
------

Developer preview. API in flux.

