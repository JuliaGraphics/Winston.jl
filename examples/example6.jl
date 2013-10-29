#!/usr/bin/env julia

using Winston

x = linspace( pi, 3pi, 60 )
c = cos(x)
s = sin(x)

p = FramedPlot(aspect_ratio=1)
setattr(p.frame1, draw_grid=true, tickdir=1)

setattr(p.x1, label="bottom", subticks=1 )
setattr(p.y1, label="left", draw_spine=false)
setattr( p.x2, label="top", range=(10,1000), log=true)

setattr(p.y2, label="right", draw_ticks=false,
    ticklabels=["-1", "-1/2", "0", "1/2", "1"])

add( p, Curve(x, c, kind="dash") )
add( p, Curve(x, s) )

#file(p, "example6.eps")
file(p, "example6.png")
