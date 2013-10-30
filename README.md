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


Getting started
---------------

Winston offers an easy to use `plot` command to create figures without any fuss. There is also an `oplot` command to add objects into already existing plots. After Winston is loaded by typing the `using Winston`, the most basic plot can be created by just writing
```julia
plot(x,y)
```
To add something to this, use
```
oplot(x2,y2)
```
And finally save it with
```julia
file("figure.png")
```

More elaborate figures can be created by using the quick option for color and line/symbolkind
```julia
plot(x,y,"r--")
```
This creates a red dashed curve. Abbreviations for colors and line/symbolkinds are same as in pythons matplotlib. The `plot` command can also take more then one set of vectors and style options, like this
```julia
plot(x,y,"b:",x2,y2,"g^")
```
which creates a blue dotted line and green triangles.
 
For even more awesome figures, we can use named variables like this
```julia
plot(x,y,symbolkind="filled circle",color=0xcc0000,xrange=[10,100],xlog=true)
```
All possible options can be found from [Winston reference sheet](https://github.com/nolta/Winston.jl/blob/master/doc/reference.md).


Documentation
-------------

* [Examples](https://github.com/nolta/Winston.jl/blob/master/doc/examples.md)

Status
------

Developer preview. API in flux.

