using Winston
if Winston.output_surface == :tk
    using Tk
elseif Winston.output_surface == :gtk
    using Gtk
else
    error("unsupported output_surface for this test")
end
if Winston.output_surface == :gtk
    # minimalistic compatibility definitions
    # must be separate from using Gtk expr above
    const Toplevel = Gtk.WindowLeaf
    pack(x...;y...) = nothing
    Canvas(w, x, y) = ((w |> (c=show(Gtk.@Canvas(x,y)))); c)
end

win = Toplevel("TestCanvas", 400, 200)
c = Canvas(win, 400, 200)
pack(c, expand=true, fill="both")

p = FramedPlot()
x = linspace(0,10,1001)
y = sin(x)
add(p, Curve(x, y, "color", "green"))

Winston.display(c, p)
