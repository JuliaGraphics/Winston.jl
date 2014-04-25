import Tk

function tkwindow(name, w, h, closecb=nothing)
    win = Tk.Window(name, w, h)
    c = Tk.Canvas(win, w, h)
    Tk.pack(c, expand = true, fill = "both")
    if !is(closecb,nothing)
        Tk.bind(win, "<Destroy>", closecb)
    end
    c
end

function tkdestroy(c::Tk.Canvas)
    w = Tk.toplevel(c)
    Tk.destroy(w)
    nothing
end

function display(c::Tk.Canvas, pc::PlotContainer)
    c.draw = let bad=false
        function (_)
            bad && return
            ctx = getgc(c)
            set_source_rgb(ctx, 1, 1, 1)
            paint(ctx)
            try
                Winston.page_compose(pc, Tk.cairo_surface(c))
            catch e
                bad = true
                isa(e, WinstonException) || rethrow(e)
                println("Winston: ", e.msg)
            end
        end
    end
    Tk.draw(c)
    Tk.update()
end

function get_context(c::Tk.Canvas, pc::PlotContainer)
    device = CairoRenderer(Tk.cairo_surface(c))
    ext_bbox = BoundingBox(0,width(c),0,height(c))
    _get_context(device, ext_bbox, pc)
end

get_context(pc::PlotContainer) = get_context(curfig(_display), pc)
