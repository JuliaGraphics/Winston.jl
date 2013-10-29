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

### Step 1: install dependencies

Winston requires cairo, pango, & tk to be installed. The package build scripts 
for the Cairo and Tk packages will attempt to install these for you, but 
there are some pre-requisites depending on whether you choose to build from source
or to use a package manager.

OS X (MacPorts):

    $ sudo port install cairo +x11
    $ sudo port install pango +x11
    $ sudo port install tk +x11
    $ export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/local/lib

OS X (Homebrew):

    $ brew tap homebrew/dupes

Ubuntu:

    $ aptitude install libcairo2 libpango1.0-0 tk-dev

If you wish to install from source, skip the above steps.

### Step 2: install package

    julia> Pkg.add("Winston")

If you are upgrading from a previous version of Winston, you may need to run
these build scripts:

    julia> Pkg.runbuildscript("Tk")
    julia> Pkg.runbuildscript("Cairo")

Documentation
-------------

* [Examples](https://github.com/nolta/Winston.jl/blob/master/doc/examples.md)
* [Plotting interface tutorial](https://github.com/natj/Winston.jl/blob/master/doc/plot_tutorial.md)
* [Reference sheet](https://github.com/nolta/Winston.jl/blob/master/doc/reference.md)

Status
------

Developer preview. API in flux.

