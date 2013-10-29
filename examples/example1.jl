#!/usr/bin/env julia

using Winston

x = linspace(0, 3pi, 100)
c = cos(x)
s = sin(x)

p = FramedPlot(
        title="title!",
        xlabel="\\Sigma x^2_i",
        ylabel="\\Theta_i")

add(p, FillBetween(x, c, x, s))
add(p, Curve(x, c, color="red"))
add(p, Curve(x, s, color="blue"))

#file(p, "example1.eps")
file(p, "example1.png")
