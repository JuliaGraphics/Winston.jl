#!/usr/bin/env julia

using Winston

p = FramedPlot(
        aspect_ratio=1,
        xrange=(0,100),
        yrange=(0,100))

n = 21
x = linspace(0, 100, n)
yA = 40 + 10randn(n)
yB = x + 5randn(n)

a = Points(x, yA, kind="circle")
setattr(a, label="a points")

b = Points(x, yB)
setattr(b, label="b points")
style(b, kind="filled circle")

s = Slope(1, (0,0), kind="dotted")
setattr(s, label="slope")

l = Legend(.1, .9, {a,b,s})

add(p, s, a, b, l)

#file(p, "example2.eps")
file(p, "example2.png")
