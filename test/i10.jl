require("Winston/src/Plot")
using Plot
p = plot(abs(sin(0:.1:10)))
Plot.setattr(p, "ylog", true)
Plot.setattr(p, "yrange", (5e-6,0.2))
