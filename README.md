
Winston : 2d vector plotting for Julia
======================================

    load("winston.jl")

    x = [-pi:0.2:pi]
    y = sin(x)

    p = FramedPlot()
    add(p, Curve(x, y))

    x11(p)
    file(p, "winston.eps")

Install
-------

Winston uses the GNU libplot library as its graphical backend:

* Fedora: `yum install plotutils`
* OS X (Homebrew): `brew install plotutils`
* Ubuntu: `aptitude install plotutils`
* Source: <http://www.gnu.org/software/plotutils/>

Then, add

    push(LOAD_PATH, "/path/to/winston/jl")

to your `~/.juliarc`.

Documentation
-------------

* [Examples](https://github.com/nolta/winston/wiki/Examples)
* [Reference](https://github.com/nolta/winston/wiki/Reference)

Status
------

Developer preview. API in flux.

