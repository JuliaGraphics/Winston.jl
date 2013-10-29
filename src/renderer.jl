type RendererState
    current::Dict{Symbol,Any}
    saved::Vector{Dict{Symbol,Any}}

    RendererState() = new(Dict{Symbol,Any}(),Dict{Symbol,Any}[])
end

function set(self::RendererState, name::Symbol, value)
    self.current[name] = value
end

function get(self::RendererState, name::Symbol, notfound=nothing)
    if haskey(self.current, name)
        return self.current[name]
    end
    for d = self.saved
        if haskey(d,name)
            return d[name]
        end
    end
    return notfound
end

function save(self::RendererState)
    unshift!(self.saved, self.current)
    self.current = Dict{Symbol,Any}()
end

function restore(self::RendererState)
    self.current = self.saved[1]
    splice!(self.saved, 1)
end

abstract Renderer

type CairoRenderer <: Renderer
    ctx::CairoContext
    state::RendererState

    function CairoRenderer(surface)
        ctx = CairoContext(surface)
        new(ctx, RendererState())
    end
end

width(r::CairoRenderer) = width(r.ctx.surface)
height(r::CairoRenderer) = height(r.ctx.surface)

# convert to postscipt pt = in/72
const xx2pt = [ "in"=>72., "pt"=>1., "mm"=>2.835, "cm"=>28.35 ]
function _str_size_to_pts(str)
    m = match(r"([\d.]+)([^\s]+)", str)
    num_xx = float64(m.captures[1])
    units = m.captures[2]
    num_pt = num_xx*xx2pt[units]
    return num_pt
end

## state commands

color_to_rgb(i::Integer) = convert(RGB, RGB24(unsigned(i)))
color_to_rgb(s::String) = color(s)

set_color(ctx::CairoContext, color) = set_source(ctx, color_to_rgb(color))

function set_clip_rect(ctx::CairoContext, bb::BoundingBox)
    rectangle(ctx, xmin(bb), ymin(bb), width(bb), height(bb))
    clip(ctx)
end

const __pl_style_func = [
    :color     => set_color,
    :linecolor => set_color,
    :fillcolor => set_color,
    :linestyle => set_line_type,
    :linekind  => set_line_type,
    :linewidth => set_line_width,
    :filltype  => set_fill_type,
    :cliprect  => set_clip_rect,
]

function set(self::CairoRenderer, key::Symbol, value)
    set(self.state, key, value)
    if key == :fontface
        fontsize = get(self, :fontsize, 12)
        set_font_face(self.ctx, "$value $(fontsize)px")
    elseif key == :fontsize
        fontface = get(self, :fontface, "sans-serif")
        set_font_face(self.ctx, "$fontface $(value)px")
    elseif haskey(__pl_style_func, key)
        __pl_style_func[key](self.ctx, value)
    end
end
set(self::CairoRenderer, key::String, value) = set(self, symbol(key), value)

function get(self::CairoRenderer, parameter::Symbol, notfound=nothing)
    return get(self.state, parameter, notfound)
end
get(self::CairoRenderer, parameter::String, notfound=nothing) = get(self, symbol(parameter), notfound)

function save_state(self::CairoRenderer)
    save(self.state)
    save(self.ctx)
end

function restore_state(self::CairoRenderer)
    restore(self.state)
    restore(self.ctx)
end

## drawing commands

stroke(cr::CairoRenderer) = stroke(cr.ctx)

move_to(self::CairoRenderer, px, py) = move_to(self.ctx, px, py)

let lastfinite = true
global line_to
function line_to(self::CairoRenderer, px, py)
    nextfinite = isfinite(px) && isfinite(py)
    if lastfinite && nextfinite
        line_to(self.ctx, px, py)
    elseif nextfinite
        move_to(self.ctx, px, py)
    end
    lastfinite = nextfinite
end
end

rel_line_to(self::CairoRenderer, px, py) = rel_line_to(self.ctx, px, py)

function line(self::CairoRenderer, px, py, qx, qy)
    move_to(self.ctx, px, py)
    line_to(self.ctx, qx, qy)
    stroke(self.ctx)
end

rect(self::CairoRenderer, px, py, qx, qy) = rectangle(self.ctx, px, py, qx-px, qy-py)

circle(self::CairoRenderer, px, py, r) = circle(self.ctx, px, py, r)

arc(self::CairoRenderer, cx, cy, px, py, qx, qy) =
    arc(self.ctx, cx, cy, px, py, qx, qy)

const symbol_funcs = {
    "asterisk" => (c, x, y, r) -> (
        move_to(c, x, y+r);
        line_to(c, x, y-r);
        move_to(c, x+0.866r, y-0.5r);
        line_to(c, x-0.866r, y+0.5r);
        move_to(c, x+0.866r, y+0.5r);
        line_to(c, x-0.866r, y-0.5r)
    ),
    "cross" => (c, x, y, r) -> (
        move_to(c, x+r, y+r);
        line_to(c, x-r, y-r);
        move_to(c, x+r, y-r);
        line_to(c, x-r, y+r)
    ),
    "diamond" => (c, x, y, r) -> (
        move_to(c, x, y+r);
        line_to(c, x+r, y);
        line_to(c, x, y-r);
        line_to(c, x-r, y);
        close_path(c)
    ),
    "dot" => (c, x, y, r) -> (
        new_sub_path(c);
        rectangle(c, x, y, 1., 1.)
    ),
    "plus" => (c, x, y, r) -> (
        move_to(c, x+r, y);
        line_to(c, x-r, y);
        move_to(c, x, y+r);
        line_to(c, x, y-r)
    ),
    "square" => (c, x, y, r) -> (
        new_sub_path(c);
        rectangle(c, x-0.866r, y-0.866r, 1.732r, 1.732r)
    ),
    "triangle" => (c, x, y, r) -> (
        move_to(c, x, y+r);
        line_to(c, x+0.866r, y-0.5r);
        line_to(c, x-0.866r, y-0.5r);
        close_path(c)
    ),
    "down-triangle" => (c, x, y, r) -> (
        move_to(c, x, y-r);
        line_to(c, x+0.866r, y+0.5r);
        line_to(c, x-0.866r, y+0.5r);
        close_path(c)
    ),
    "right-triangle" => (c, x, y, r) -> (
        move_to(c, x+r, y);
        line_to(c, x-0.5r, y+0.866r);
        line_to(c, x-0.5r, y-0.866r);
        close_path(c)
    ),
    "left-triangle" => (c, x, y, r) -> (
        move_to(c, x-r, y);
        line_to(c, x+0.5r, y+0.866r);
        line_to(c, x+0.5r, y-0.866r);
        close_path(c)
    ),
}

function symbols(self::CairoRenderer, x, y)
    fullname = get(self.state, :symbolkind, "square")
    size = get(self.state, :symbolsize, 0.01)

    splitname = split(fullname)
    name = pop!(splitname)
    filled = "solid" in splitname || "filled" in splitname

    default_symbol_func = (ctx,x,y,r) -> (
        new_sub_path(ctx);
        circle(ctx,x,y,r)
    )
    symbol_func = get(symbol_funcs, name, default_symbol_func)

    save(self.ctx)
    set_dash(self.ctx, Float64[])
    new_path(self.ctx)
    for i = 1:min(length(x),length(y))
        symbol_func(self.ctx, x[i], y[i], 0.5*size)
    end
    if filled
        fill_preserve(self.ctx)
    end
    stroke(self.ctx)
    restore(self.ctx)
end

function curve(self::CairoRenderer, x::AbstractVector, y::AbstractVector)
    n = min(length(x), length(y))
    if n <= 0
        return
    end
    new_path(self.ctx)
    i = 1
    while i <= length(x) && (!isfinite(x[i]) || !isfinite(y[i]))
        i += 1
    end
    if i <= length(x)
        move_to(self.ctx, x[i], y[i])
        for i = i+1:n
            line_to(self, x[i], y[i])
            if i == n || (i&127)==0
                stroke(self.ctx)
                if i < n
                    move_to(self, x[i], y[i])
                end
            end
        end
    end
end

image(r::CairoRenderer, src, x, y, w, h) = image(r.ctx, src, x, y, w, h)

function polygon(self::CairoRenderer, points::Vector)
    polygon(self.ctx, points)
    fill(self.ctx)
end

function layout_text(self::CairoRenderer, str::String)
    set_latex(self.ctx, str, get(self,:fontsize))
end

function text(self::CairoRenderer, x::Real, y::Real, str::String; kwargs...)
    return text(self.ctx, x, y, set_latex(self.ctx, str, get(self,:fontsize)); markup=true, kwargs...)
end

function textwidth(self::CairoRenderer, str)
    layout_text(self, str)
    extents = get_layout_size(self.ctx)
    extents[1]
end

function textheight(self::CairoRenderer, str)
    get(self.state, :fontsize) ## XXX: kludge?
end
