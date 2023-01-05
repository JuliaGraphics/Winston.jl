using Gtk4
include("canvasgtkcompat.jl")

win = Toplevel("TestCanvas", 400, 200)
c = Canvas(win, 400, 200)
pack(c, expand=true, fill="both")

p = FramedPlot()
x = range(0,stop=10,length=1001)
y = sin.(x)
add(p, Curve(x, y, "color", colorant"green"))

Winston.display(c, p)
