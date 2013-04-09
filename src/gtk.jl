import GTK
import Base.repl_show

function GTKdrawingwindow(name, w, h, closecb=nothing)
    win = GTK.Window(name, w, h)
    c = GTK.Canvas(win)
    #Tk.pack(c)
    #if !is(closecb,nothing)
    #    ccb = Tk.tcl_callback(closecb)
    #    Tk.tcl_eval("bind $(win.path) <Destroy> $ccb")
    #end
    GTK.cairo_surface(c), win
end

_saved_gtk_renderer = nothing
_saved_gtk_win = nothing

function gtk(self::PlotContainer, args...)
    global _saved_gtk_renderer, _saved_gtk_win
    opts = Winston.args2dict(args...)
    width = has(opts,"width") ? opts["width"] : Winston.config_value("window","width")
    height = has(opts,"height") ? opts["height"] : Winston.config_value("window","height")
    reuse_window = isinteractive() #&& Winston.config_value("window","reuse")
    device = _saved_gtk_renderer
    win = _saved_gtk_win
    if device === nothing || win == nothing || !reuse_window || win.destroyed
        device, win = GTKdrawingwindow("Julia", width, height,
                                       (x...)->(_saved_gtk_renderer=nothing))
        _saved_gtk_renderer = device
        _saved_gtk_win = win
    end
    Winston.page_compose(self, device, !reuse_window)
end

function repl_show(io::IO, p::PlotContainer)
    print("<plot>")
end

function display(args...)
    gtk(args...)
end
