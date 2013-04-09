import Tk
import Base.repl_show

function drawingwindow(name, w, h, closecb=nothing)
    win = Tk.Window(name, w, h)
    c = Tk.Canvas(win)
    Tk.pack(c)
    if !is(closecb,nothing)
        ccb = Tk.tcl_callback(closecb)
        Tk.tcl_eval("bind $(win.path) <Destroy> $ccb")
    end
    c
end

_saved_canvas = nothing

function tk(self::PlotContainer, args...)
    global _saved_canvas
    opts = Winston.args2dict(args...)
    width = has(opts,"width") ? opts["width"] : Winston.config_value("window","width")
    height = has(opts,"height") ? opts["height"] : Winston.config_value("window","height")
    reuse_window = isinteractive() #&& Winston.config_value("window","reuse")
    device = _saved_canvas
    if device === nothing || !reuse_window
        device = drawingwindow("Julia", width, height,
                               (x...)->(_saved_canvas=nothing))
        _saved_canvas = device
    end
    cr = Tk.cairo_context(device)
    Cairo.set_source_rgb(cr, 1, 1, 1)
    Cairo.paint(cr)
    Winston.page_compose(self, Tk.cairo_surface(device))
    Tk.reveal(device)
    Tk.tcl_doevent()
    self
end

function repl_show(io::IO, p::PlotContainer)
    print("<plot>")
end

function display(args...)
    tk(args...)
end
