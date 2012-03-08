#!/usr/bin/env julia

load("winston.jl")

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

x11(p)
#file(p, "example4.eps")
#file(p, "example4.png")
