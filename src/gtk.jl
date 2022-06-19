import Gtk4

function gtkwindow(name, w, h, closecb=nothing)
    c = Gtk4.GtkCanvas()
    win = Gtk4.GtkWindow(c, name, w, h)

    if closecb !== nothing
        Gtk4.signal_connect(win, :destroy) do widget
            closecb()
        end
    end
    Gtk4.show(c)
end

function display(c::Gtk4.GtkCanvas, pc::PlotContainer)
    Gtk4.@guarded function redraw(widget)
        ctx = getgc(c)
        set_source_rgb(ctx, 1, 1, 1)
        paint(ctx)
        try
            Winston.page_compose(pc, Gtk4.cairo_surface(c))
        catch e
            isa(e, WinstonException) || rethrow(e)
            println("Winston: ", e.msg)
        end
    end
    Gtk4.draw(redraw, c)
end

gtkdestroy(c::Gtk4.GtkCanvas) = Gtk4.destroy(Gtk4.toplevel(c))

# JWN: copied the following from tk.jl, but I don't know
# what it does, so I can't make sure it works
#
function get_context(c::Gtk4.GtkCanvas, pc::PlotContainer)
    device = CairoRenderer(Gtk4.cairo_surface(c))
    ext_bbox = BoundingBox(0,width(c),0,height(c))
    _get_context(device, ext_bbox, pc)
end

get_context(pc::PlotContainer) = get_context(curfig(_display), pc)
