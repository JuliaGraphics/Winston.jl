import Gtk

function Gtkdrawingwindow(name, w, h, closecb=nothing)
    c = Gtk.Canvas()
    win = Gtk.Window(c, name, w, h)
    if closecb !== nothing
        Gtk.on_signal_destroy(closecb, win)
    end
    c, win
end

_saved_gtk_renderer = nothing
function _saved_gtk_destroyed(::Ptr, widget)
    global _saved_gtk_renderer = nothing
    nothing
end
function gtk(self::PlotContainer, args...)
    global _saved_gtk_renderer, _saved_gtk_win
    opts = Winston.args2dict(args...)
    width = get(opts, :width, Winston.config_value("window","width"))
    height = get(opts, :height, Winston.config_value("window","height"))
    device = _saved_gtk_renderer
    if device === nothing
        device, win = Gtkdrawingwindow("Julia", width, height, _saved_gtk_destroyed)
        _saved_gtk_renderer = device
    end
    display(device, self)
    self
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
