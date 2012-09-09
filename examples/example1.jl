#!/usr/bin/env julia

load("winston.jl")
import Winston.*

x = linspace( 0, 3pi, 100 )
c = cos(x)
s = sin(x)

p = FramedPlot()
setattr(p, "title", "title!")

setattr(p, "xlabel", L"\Sigma x^2_i")
setattr(p, "ylabel", L"\Theta_i")

add(p, FillBetween(x, c, x, s) )
add(p, Curve(x, c, "color", "red") )
add(p, Curve(x, s, "color", "blue") )

#file(p, "example1.eps")
file(p, "example1.png")
