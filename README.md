Winston: 2D Plotting for Julia
==============================

    using Winston

    x = [-pi:0.2:pi]
    y = sin(x)

    p = FramedPlot()
    add(p, Curve(x, y))

    Winston.display(p)      # Display the plot on-screen
    file(p, "winston.eps")  # Save the plot to a file

Installation
------------

    julia> Pkg.add("Winston")

Documentation
-------------

* [Examples](https://github.com/nolta/Winston.jl/blob/master/doc/examples.md)

Status
------

Developer preview. API in flux.

