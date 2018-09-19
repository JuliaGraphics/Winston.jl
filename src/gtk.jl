import Gtk

function gtkwindow(name, w, h, closecb=nothing)
    c = Gtk.Canvas()
    win = Gtk.Window(c, name, w, h)

    if closecb !== nothing
        Gtk.signal_connect(win, :destroy) do widget
            closecb()
        end
    end
    Gtk.showall(c)
end

function display(c::Gtk.Canvas, pc::PlotContainer)
    Gtk.@guarded function redraw(widget)
        ctx = getgc(c)
        set_source_rgb(ctx, 1, 1, 1)
        paint(ctx)
        try
            Winston.page_compose(pc, Gtk.cairo_surface(c))
        catch e
            isa(e, WinstonException) || rethrow(e)
            println("Winston: ", e.msg)
        end
    end
    Gtk.draw(redraw, c)
end

gtkdestroy(c::Gtk.Canvas) = Gtk.destroy(Gtk.toplevel(c))

# JWN: copied the following from tk.jl, but I don't know
# what it does, so I can't make sure it works
#
function get_context(c::Gtk.Canvas, pc::PlotContainer)
    device = CairoRenderer(Gtk.cairo_surface(c))
    ext_bbox = BoundingBox(0,width(c),0,height(c))
    _get_context(device, ext_bbox, pc)
end

get_context(pc::PlotContainer) = get_context(curfig(_display), pc)
