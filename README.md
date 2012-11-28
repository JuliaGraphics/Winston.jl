
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

### Step 1: install dependencies

Winston requires cairo, pango, & tk to be installed.

OS X (MacPorts):

    $ sudo port install cairo +x11
    $ sudo port install pango +x11
    $ sudo port install tk +x11

Ubuntu:

    $ aptitude install libcairo2 libpango1.0-0 tk-dev

### Step 2: build Tk wrapper

    $ cd julia
    $ make -C deps install-tk-wrapper

### Step 3: install package

    julia> load("pkg.jl")
    julia> Pkg.add("Winston")

Documentation
-------------

* [Examples](https://github.com/nolta/Winston.jl/blob/master/doc/examples.md)

Status
------

Developer preview. API in flux.

