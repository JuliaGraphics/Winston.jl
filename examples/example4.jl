#!/usr/bin/env julia

using Winston

x = linspace(0., 2pi, 40)
s = sin(x)
c = cos(x)

inset = FramedPlot(title="inset")
setattr(inset.frame, draw_ticks=false)

add( inset, Curve(x, s, kind="dashed") )

p = FramedPlot(aspect_ratio=1)
setattr(p.frame, tickdir=+1, draw_spine=false)

add( p, SymmetricErrorBarsY(x, s, 0.2*ones(length(x))) )
add( p, Points(x, s, "color", "red") )
add( p, PlotInset((.6,.6), (.95,.95), inset) )

#file(p, "example4.eps")
file(p, "example4.png")
