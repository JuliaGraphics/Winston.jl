Winston: 2D Plotting for Julia
==============================

[![Build Status](https://travis-ci.org/nolta/Winston.jl.svg?branch=master)](https://travis-ci.org/nolta/Winston.jl)
[![Coverage Status](https://coveralls.io/repos/github/nolta/Winston.jl/badge.svg)](https://coveralls.io/github/nolta/Winston.jl)
[![Winston](http://pkg.julialang.org/badges/Winston_0.5.svg)](http://pkg.julialang.org/?pkg=Winston)
[![Winston](http://pkg.julialang.org/badges/Winston_0.6.svg)](http://pkg.julialang.org/?pkg=Winston)

Installation
------------

```julia
julia> Pkg.add("Winston")
```

Getting started
---------------

Winston offers an easy to use `plot` command to create figures without any
fuss. After Winston is loaded by typing `using Winston`, the most basic
plot can be created by just writing

```julia
julia> plot(x, y)
```

There is also an `oplot` command to add objects into already existing
plots. To add something to this, use

```julia
julia> oplot(x2, y2)
```

And finally save it with

```julia
julia> savefig("figure.png")   # .eps, .pdf, & .svg are also supported
```

More elaborate figures can be created by using the quick option for color,
line, and symbols

```julia
julia> plot(x, y, "r--")
```

This creates a red dashed curve. Abbreviations for colors and lines/symbols
are same as in matplotlib. The `plot` command can also take more then
one set of vectors and style options, like this

```julia
julia> plot(x, y, "b:", x2, y2, "g^")
```

which creates a blue dotted line and green triangles.

Documentation
-------------

Hosted by [Read The Docs](http://winston.rtfd.org/).
