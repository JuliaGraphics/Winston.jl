using Tk
using Winston

win = Toplevel("TestCanvas", 400, 200)
c = Canvas(win, 400, 200)
pack(c, expand=true, fill="both")

p = FramedPlot()
x = linspace(0,10,1001)
y = sin(x)
add(p, Curve(x, y, "color", "green"))

Winston.display(c, p)
