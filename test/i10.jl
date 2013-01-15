using Winston
p = plot(abs(sin(0:.1:10)))
setattr(p, "ylog", true)
setattr(p, "yrange", (5e-6,0.2))
