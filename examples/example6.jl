#!/usr/bin/env julia

load("winston.jl")
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

#file(p, "example6.eps")
file(p, "example6.png")
