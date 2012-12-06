
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
    $ export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/local/lib

OS X (Homebrew):

**Homebrew tk is broken -- we recommend using macports.**

    $ brew tap homebrew/dupes
    $ brew install cairo pango tk

Note: installing tk with the `--enable-aqua` option appears to break Winston.
Also, installation can be tricky if both Apple's X11.app and XQuartz are
present.

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

