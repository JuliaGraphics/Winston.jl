#!/usr/bin/env julia

load("winston.jl")
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

#file(a, "example5.eps")
file(a, "example5.png")
