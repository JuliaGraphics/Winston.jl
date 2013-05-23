#!/usr/bin/env julia

using Winston
 
x = linspace( 0., 2pi, 30 )
y = sin(x)

p = FramedArray( 2, 2, "title", "title" )
setattr( p, "aspect_ratio", 0.75 )
setattr( p, "xlabel", "x label" )
setattr( p, "ylabel", "y label" )
setattr( p, "uniform_limits", true )
setattr( p, "cellspacing", 1. )

add( p, LineY(0, "type", "dot") )

add( p[1,1], Curve(x, .25*y) )
add( p[1,2], Curve(x, .50*y) )
add( p[2,1], Curve(x, .75*y) )
add( p[2,2], Curve(x, y) )

#file(p, "example5.eps")
file(p, "example5.png")
