#!/usr/bin/env julia

using Winston

p = FramedPlot(
        title="Title",
        xlabel="X axis",
        ylabel="Y axis")

add(p, Histogram(hist(randn(1000))...))
add(p, PlotLabel(.5, .5, "Histogram", color=0xcc0000))

t1 = Table(1, 2)
t1[1,1] = p
t1[1,2] = p

t2 = Table(2, 1)
t2[1,1] = t1
t2[2,1] = p

#file(t2, "example3.eps")
file(t2, "example3.png")

p = t2
