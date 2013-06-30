Example 1
---------

![Example 1](http://www.cita.utoronto.ca/~nolta/julia/winston/examples/example1.png)

``` julia
using Winston

x = linspace( 0, 3pi, 100 )
c = cos(x)
s = sin(x)

p = FramedPlot()
setattr(p, "title", "title!")

setattr(p, "xlabel", "\\Sigma x^2_i")
setattr(p, "ylabel", "\\Theta_i")

add(p, FillBetween(x, c, x, s) )
add(p, Curve(x, c, "color", "red") )
add(p, Curve(x, s, "color", "blue") )

file(p, "example1.png")
```

Example 2
---------

![Example 2](http://www.cita.utoronto.ca/~nolta/julia/winston/examples/example2.png)

``` julia
using Winston

p = FramedPlot()
setattr(p, "xrange", (0,100))
setattr(p, "yrange", (0,100))
setattr(p, "aspect_ratio", 1)

n = 21
x = linspace( 0, 100, n )
yA = 40 + 10randn(n)
yB = x + 5randn(n)

a = Points( x, yA, "type", "circle" )
setattr(a, "label", "a points")

b = Points( x, yB )
setattr(b, "label", "b points")
style(b, "type", "filled circle" )

s = Slope( 1, (0,0), "type", "dotted" )
setattr(s, "label", "slope")

l = Legend( .1, .9, {a,b,s} )

add( p, s, a, b, l )
file(p, "example2.png")
```

Example 3
---------

![Example 3](http://db.tt/SQMcAgQi)

``` julia
using Winston

p = FramedPlot()
setattr(p, "title", "Title")
setattr(p, "xlabel", "X axis")
setattr(p, "ylabel", "Y axis")

add( p, Histogram(hist(randn(1000))...) )
add( p, PlotLabel(.5, .5, "Histogram", "color", 0xcc0000) )

t1 = Table( 1, 2 )
t1[1,1] = p
t1[1,2] = p

t2 = Table( 2, 1 )
t2[1,1] = t1
t2[2,1] = p

file(t2, "example3.png")
```

Example 4
---------

![Example 4](http://www.cita.utoronto.ca/~nolta/julia/winston/examples/example4.png)

``` julia
using Winston

x = linspace(0., 2pi, 40)
s = sin(x)
c = cos(x)

inset = FramedPlot()
setattr(inset, "title", "inset")
setattr(inset.frame, "draw_ticks", false)

add( inset, Curve(x, s, "type", "dashed") )

p = FramedPlot()
setattr(p, "aspect_ratio", 1.)
setattr(p.frame, "tickdir", +1)
setattr(p.frame, "draw_spine", false)

add( p, SymmetricErrorBarsY(x, s, 0.2*ones(length(x))) )
add( p, Points(x, s, "color", "red") )
add( p, PlotInset((.6,.6), (.95,.95), inset) )

file(p, "example4.png")
```

Example 5
---------

![Example 5](http://www.cita.utoronto.ca/~nolta/julia/winston/examples/example5.png)

``` julia
using Winston

x = linspace( 0., 2pi, 30 )
y = sin(x)

a = FramedArray( 2, 2, "title", "title" )
setattr( a, "aspect_ratio", 0.75 )
setattr( a, "xlabel", "x label" )
setattr( a, "ylabel", "y label" )
setattr( a, "uniform_limits", true )
setattr( a, "cellspacing", 1. )

add( a, LineY(0, "type", "dot") )

add( a[1,1], Curve(x, .25*y) )
add( a[1,2], Curve(x, .50*y) )
add( a[2,1], Curve(x, .75*y) )
add( a[2,2], Curve(x, y) )

file(a, "example5.png")
```

Example 6
---------

![Example 6](http://www.cita.utoronto.ca/~nolta/julia/winston/examples/example6.png)

``` julia
using Winston

x = linspace( pi, 3pi, 60 )
c = cos(x)
s = sin(x)

p = FramedPlot()
setattr( p, "aspect_ratio", 1 )
setattr( p.frame1, "draw_grid", true )
setattr( p.frame1, "tickdir", 1 )

setattr( p.x1, "label", "bottom" )
setattr( p.x1, "subticks", 1 )

setattr( p.y1, "label", "left" )
setattr( p.y1, "draw_spine", false )

setattr( p.x2, "label", "top" )
setattr( p.x2, "range", (10,1000) )
setattr( p.x2, "log", true )

setattr( p.y2, "label", "right" )
setattr( p.y2, "draw_ticks", false )
setattr( p.y2, "ticklabels", [ "-1", "-1/2", "0", "1/2", "1" ] )

add( p, Curve(x, c, "type", "dash") )
add( p, Curve(x, s) )
file(p, "example6.png")
```
