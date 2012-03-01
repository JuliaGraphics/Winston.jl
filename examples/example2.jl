#!/usr/bin/env julia

load("winston.jl")

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

x11(p)
file(p, "example2.eps")
file(p, "example2.png")
