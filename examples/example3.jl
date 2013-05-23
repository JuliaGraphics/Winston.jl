#!/usr/bin/env julia

using Winston

x = linspace( 0, 3pi, 30)
y = sin(x)

p = FramedPlot()
setattr(p, "title", "Title")
setattr(p, "xlabel", "X axis")
setattr(p, "ylabel", "Y axis")

add( p, Histogram(y, 1) )
add( p, PlotLabel(.5, .5, "Histogram", "color", 0xcc0000) )

t1 = Table( 1, 2 )
t1[1,1] = p
t1[1,2] = p

t2 = Table( 2, 1 )
t2[1,1] = t1
t2[2,1] = p

#file(t2, "example3.eps")
file(t2, "example3.png")
