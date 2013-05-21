import Tk
import Base.repl_show

function drawingwindow(name, w, h, closecb=nothing)
    win = Tk.Window(name, w, h)
    c = Tk.Canvas(win, w, h)
    Tk.pack(c, {:expand => true, :fill => "both"})
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
    width = get(opts,"width",Winston.config_value("window","width"))
    height = get(opts,"height",Winston.config_value("window","height"))
    reuse_window = isinteractive() #&& Winston.config_value("window","reuse")
    device = _saved_canvas
    if device === nothing || !reuse_window
        device = drawingwindow("Julia", width, height,
                               (x...)->(_saved_canvas=nothing))
        _saved_canvas = device
    end
    device.redraw = function (_)
        cr = Tk.getgc(device)
        Cairo.set_source_rgb(cr, 1, 1, 1)
        Cairo.paint(cr)
        Winston.page_compose(self, Tk.cairo_surface(device))
        Tk.reveal(device)
        Tk.tcl_doevent()
    end
    device.redraw(device)
    self
end

function repl_show(io::IO, p::PlotContainer)
    print("<plot>")
end

function display(args...)
    tk(args...)
end

function display(c::Tk.Canvas, pc::PlotContainer)
    c.redraw = function (_)
        ctx = Base.Graphics.getgc(c)
        Base.Graphics.set_source_rgb(ctx, 1, 1, 1)
        Base.Graphics.paint(ctx)
        Winston.page_compose(pc, Tk.cairo_surface(c))
    end
    c.redraw(c)
end
