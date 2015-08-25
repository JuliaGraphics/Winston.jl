using Winston, Colors
if Winston.output_surface == :tk
    using Tk
elseif Winston.output_surface == :gtk
    using Gtk
    include("canvasgtkcompat.jl")
else
    error("unsupported output_surface for this test")
end

win = Toplevel("TestCanvas", 400, 200)
c = Canvas(win, 400, 200)
pack(c, expand=true, fill="both")

p = FramedPlot()
x = linspace(0,10,1001)
y = sin(x)
add(p, Curve(x, y, "color", colorant"green"))

Winston.display(c, p)
