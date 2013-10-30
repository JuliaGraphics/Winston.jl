Winston: 2D Plotting for Julia
==============================

Installation
------------

    julia> Pkg.add("Winston")


Getting started
---------------

Winston offers an easy to use `plot` command to create figures without any
fuss. After Winston is loaded by typing `using Winston`, the most basic
plot can be created by just writing

```jlcon
julia> plot(x, y)
```

There is also an `oplot` command to add objects into already existing
plots. To add something to this, use

```jlcon
julia> oplot(x2, y2)
```

And finally save it with

```jlcon
julia> file("figure.png")
```

More elaborate figures can be created by using the quick option for color,
line, and symbols

```jlcon
julia> plot(x, y, "r--")
```

This creates a red dashed curve. Abbreviations for colors and lines/symbols
are same as in matplotlib. The `plot` command can also take more then
one set of vectors and style options, like this

```jlcon
julia> plot(x, y, "b:", x2, y2, "g^")
```

which creates a blue dotted line and green triangles.
 
Declarative interface
---------------------

    using Winston

    x = [-pi:0.2:pi]
    y = sin(x)

    p = FramedPlot()
    add(p, Curve(x, y))

    Winston.display(p)      # Display the plot on-screen
    file(p, "winston.eps")  # Save the plot to a file

Documentation is a bit sparse at the moment, but see the
[examples](https://github.com/nolta/Winston.jl/blob/master/doc/examples.md).
