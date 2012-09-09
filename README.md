
Winston : 2d vector plotting for Julia
======================================

    load("winston.jl")
    import Winston.*

    x = [-pi:0.2:pi]
    y = sin(x)

    p = FramedPlot()
    add(p, Curve(x, y))

    file(p, "winston.eps")

Install
-------

Winston is distributed with Julia, and uses Cairo as its
graphical backend:

* OS X (macports): `port install cairo pango`
* Ubuntu: `aptitude install libcairo2 libpango1.0-0`

Documentation
-------------

* [Examples](https://github.com/nolta/winston/wiki/Examples)
* [Reference](https://github.com/nolta/winston/wiki/Reference)

Status
------

Developer preview. API in flux.

