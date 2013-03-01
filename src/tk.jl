import Tk
import Base.repl_show

TkRenderer(name, w, h) = TkRenderer(name, w, h, nothing)
function TkRenderer(name, w, h, closecb)
    win = Tk.Window(name, w, h)
    c = Tk.Canvas(win)
    Tk.pack(c)
    if !is(closecb,nothing)
        ccb = Tk.tcl_callback(closecb)
        Tk.tcl_eval("bind $(win.path) <Destroy> $ccb")
    end
    r = Cairo.CairoRenderer(Tk.cairo_surface(c))
    r.upperright = (w,h)
    r.on_open = () -> (cr = Tk.cairo_context(c); Cairo.set_source_rgb(cr, 1, 1, 1); Cairo.paint(cr))
    r.on_close = () -> (Tk.reveal(c); Tk.tcl_doevent())
    r
end

_saved_tk_renderer = nothing

function tk(self::PlotContainer, args...)
    global _saved_tk_renderer
    opts = Winston.args2dict(args...)
    width = has(opts,"width") ? opts["width"] : Winston.config_value("window","width")
    height = has(opts,"height") ? opts["height"] : Winston.config_value("window","height")
    reuse_window = isinteractive() #&& Winston.config_value("window","reuse")
    device = _saved_tk_renderer
    if device === nothing || !reuse_window
        device = TkRenderer("Julia", width, height,
                            (x...)->(_saved_tk_renderer=nothing))
        _saved_tk_renderer = device
    end
    Winston.page_compose(self, device, !reuse_window)
    if reuse_window
        device.on_close()
    end
    self
end

function repl_show(io::IO, p::PlotContainer)
    print("<plot>")
end

function display(args...)
    tk(args...)
end
