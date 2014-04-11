import Gtk

function gtkwindow(name, w, h, closecb=nothing)
    c = Gtk.Canvas()
    win = Gtk.Window(c, name, w, h)
    if closecb !== nothing
        Gtk.on_signal_destroy(closecb, win)
    end
    c
end

function display(c::Gtk.Canvas, pc::PlotContainer)
    c.draw = function(_)
        ctx = getgc(c)
        set_source_rgb(ctx, 1, 1, 1)
        paint(ctx)
        Winston.page_compose(pc, Gtk.cairo_surface(c))
    end
    Gtk.draw(c)
end
