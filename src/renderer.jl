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
boundingbox(c::CairoRenderer) = BoundingBox(0., width(c), 0., height(c))

# convert to postscipt pt = in/72
const xx2pt = @Dict( "in"=>72., "pt"=>1., "mm"=>2.835, "cm"=>28.35 )
function _str_size_to_pts(str)
    m = match(r"([\d.]+)([^\s]+)", str)
    num_xx = parse(Float64, m.captures[1])
    units = m.captures[2]
    num_pt = num_xx*xx2pt[units]
    return num_pt
end

## state commands

color_to_rgb(i::Integer) = convert(RGB, RGB24(unsigned(i)))
color_to_rgb(s::String) = color(s)
color_to_rgb(rgb::@compat(Tuple{Real,Real,Real})) = RGB(rgb...)
color_to_rgb(cv::Color) = convert(RGB, cv)
color_to_rgb(cv::TransparentColor) = cv

set_color(ctx::CairoContext, color) = set_source(ctx, color_to_rgb(color))

function set_clip_rect(ctx::CairoContext, bb::BoundingBox)
    rectangle(ctx, xmin(bb), ymin(bb), width(bb), height(bb))
    clip(ctx)
end

const __pl_style_func = @Dict(
    :color     => set_color,
    :linecolor => set_color,
    :fillcolor => set_color,
    :linestyle => set_line_type,
    :linekind  => set_line_type,
    :linewidth => set_line_width,
    :filltype  => set_fill_type,
    :cliprect  => set_clip_rect,
)

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
line_to(self::CairoRenderer, px, py) = line_to(self.ctx, px, py)
rel_line_to(self::CairoRenderer, px, py) = rel_line_to(self.ctx, px, py)

function line(self::CairoRenderer, px, py, qx, qy)
    move_to(self.ctx, px, py)
    line_to(self.ctx, qx, qy)
    stroke(self.ctx)
end

const symbol_funcs = @Dict(
    "asterisk" => (c, x, y, r) -> (
        move_to(c, x, y+r);
        line_to(c, x, y-r);
        move_to(c, x+0.866r, y-0.5r);
        line_to(c, x-0.866r, y+0.5r);
        move_to(c, x+0.866r, y+0.5r);
        line_to(c, x-0.866r, y-0.5r)
    ),
    "circle" => (c, x, y, r) -> (
        new_sub_path(c);
        circle(c, x, y, r)
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
)

function symbols(self::CairoRenderer, x, y)
    fullname = get(self.state, :symbolkind, "circle")
    size = get(self.state, :symbolsize, 0.01)

    splitname = split(fullname)
    name = pop!(splitname)
    filled = "solid" in splitname || "filled" in splitname

    default_symbol_func = symbol_funcs["circle"]
    symbol_func = get(symbol_funcs, name, default_symbol_func)

    save(self.ctx)
    set_dash(self.ctx, Float64[])
    new_path(self.ctx)
    for i = 1:min(length(x),length(y))
        symbol_func(self.ctx, x[i], y[i], size)
    end
    if filled
        fill_preserve(self.ctx)
    end
    stroke(self.ctx)
    restore(self.ctx)
end

function curve(self::CairoRenderer, x::AbstractArray, y::AbstractArray)
    n = min(length(x), length(y))
    n > 0 || return
    new_path(self.ctx)

    lo = 1
    while lo < n
        while lo <= n && !(isfinite(x[lo]) && isfinite(y[lo]))
            lo += 1
        end

        hi = lo + 1
        while hi <= n &&  (isfinite(x[hi]) && isfinite(y[hi]))
            hi += 1
        end
        hi -= 1

        if lo < hi
            move_to(self, x[lo], y[lo])
            for i = (lo+1):hi
                line_to(self, x[i], y[i])
                if i < hi && (i & 127) == 0
                    stroke(self.ctx)
                    move_to(self, x[i], y[i])
                end
            end
            stroke(self.ctx)
        end

        lo = hi + 1
    end
end

image(r::CairoRenderer, src, x, y, w, h) = Cairo.image(r.ctx, src, x, y, w, h)

function polygon(self::CairoRenderer, points::Vector)
    polygon(self.ctx, points)
    fill(self.ctx)
end

function rectangle(self::CairoRenderer, bbox::BoundingBox, filled::Bool=true)
    rectangle(self.ctx, bbox)
    filled ? fill(self.ctx) : stroke(self.ctx)
end

function layout_text(self::CairoRenderer, str::String)
    set_latex(self.ctx, str, get(self,:fontsize))
end

function textdraw(self::CairoRenderer, x::Real, y::Real, str::String; kwargs...)
    return Cairo.text(self.ctx, x, y, set_latex(self.ctx, str, get(self,:fontsize)); markup=true, kwargs...)
end

function textwidth(self::CairoRenderer, str)
    layout_text(self, str)
    extents = get_layout_size(self.ctx)
    extents[1]
end

function textheight(self::CairoRenderer, str)
    get(self.state, :fontsize) ## XXX: kludge?
end
