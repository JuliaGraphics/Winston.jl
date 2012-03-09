
abstract Canvas2D
abstract Renderer

_jl_libcairo = dlopen("libcairo")

# -----------------------------------------------------------------------------

type CairoSurface
    ptr::Ptr{Void}
    kind::Symbol

    function CairoSurface(ptr::Ptr{Void}, kind::Symbol)
        self = new(ptr, kind)
        finalizer(self, destroy)
        self
    end
end

function destroy(surface::CairoSurface)
    ccall(dlsym(_jl_libcairo,:cairo_surface_destroy),
        Void, (Ptr{Void},), surface.ptr)
end

function status(surface::CairoSurface)
    ccall(dlsym(_jl_libcairo,:cairo_surface_status),
        Int32, (Ptr{Void},), surface.ptr)
end

function CairoRGBSurface(w::Integer, h::Integer)
    ptr = ccall(dlsym(_jl_libcairo,:cairo_image_surface_create),
        Ptr{Void}, (Int32,Int32,Int32), 1, w, h)
    surface = CairoSurface(ptr, :rgb)
    @assert status(surface) == 0
    surface
end

function CairoPDFSurface(filename::String, w_pts::Real, h_pts::Real)
    ptr = ccall(dlsym(_jl_libcairo,:cairo_pdf_surface_create), Ptr{Void},
        (Ptr{Uint8},Float64,Float64), cstring(filename), w_pts, h_pts)
    CairoSurface(ptr, :pdf)
end

function write_to_png(surface::CairoSurface, filename::String)
    ccall(dlsym(_jl_libcairo,:cairo_surface_write_to_png), Void,
        (Ptr{Uint8},Ptr{Uint8}), surface.ptr, cstring(filename))
end

# -----------------------------------------------------------------------------

type CairoContext <: Canvas2D
    ptr::Ptr{Void}
    surface::CairoSurface

    function CairoContext(surface::CairoSurface)
        ptr = ccall(dlsym(_jl_libcairo,:cairo_create),
            Ptr{Void}, (Ptr{Void},), surface.ptr)
        self = new(ptr, surface)
        finalizer(self, destroy)
        self
    end
end

macro _CTX_FUNC_V(NAME, FUNCTION)
    quote
        ($NAME)(ctx::CairoContext) =
            ccall(dlsym(_jl_libcairo,$string(FUNCTION)),
                Void, (Ptr{Void},), ctx.ptr)
    end
end

@_CTX_FUNC_V destroy cairo_destroy
@_CTX_FUNC_V save cairo_save
@_CTX_FUNC_V restore cairo_restore
@_CTX_FUNC_V show_page cairo_show_page
@_CTX_FUNC_V clip cairo_clip
@_CTX_FUNC_V clip_preserve cairo_clip_preserve
@_CTX_FUNC_V fill cairo_fill
@_CTX_FUNC_V fill_preserve cairo_fill_preserve
@_CTX_FUNC_V new_path cairo_new_path
@_CTX_FUNC_V close_path cairo_close_path
@_CTX_FUNC_V paint cairo_paint
@_CTX_FUNC_V stroke cairo_stroke
@_CTX_FUNC_V stroke_preserve cairo_stroke_preserve

const delete = destroy

macro _CTX_FUNC_I(NAME, FUNCTION)
    quote
        ($NAME)(ctx::CairoContext, i0::Integer) =
            ccall(dlsym(_jl_libcairo,$string(FUNCTION)),
                Void, (Ptr{Void},Int32), ctx.ptr, i0)
    end
end

@_CTX_FUNC_I set_fill_type cairo_set_fill_rule

macro _CTX_FUNC_D(NAME, FUNCTION)
    quote
        ($NAME)(ctx::CairoContext, d0::Real) =
            ccall(dlsym(_jl_libcairo,$string(FUNCTION)),
                Void, (Ptr{Void},Float64), ctx.ptr, d0)
    end
end

@_CTX_FUNC_D set_line_width cairo_set_line_width
@_CTX_FUNC_D set_font_size cairo_set_font_size

macro _CTX_FUNC_DD(NAME, FUNCTION)
    quote
        ($NAME)(ctx::CairoContext, d0::Real, d1::Real) =
            ccall(dlsym(_jl_libcairo,$string(FUNCTION)),
                Void, (Ptr{Void},Float64,Float64), ctx.ptr, d0, d1)
    end
end

@_CTX_FUNC_DD move cairo_move_to
@_CTX_FUNC_DD lineto cairo_line_to
@_CTX_FUNC_DD linetorel cairo_rel_line_to

macro _CTX_FUNC_DDD(NAME, FUNCTION)
    quote
        ($NAME)(ctx::CairoContext, d0::Real, d1::Real, d2::Real) =
            ccall(dlsym(_jl_libcairo,$string(FUNCTION)),
                Void, (Ptr{Void},Float64,Float64,Float64), ctx.ptr, d0, d1, d2)
    end
end

@_CTX_FUNC_DDD set_source_rgb cairo_set_source_rgb

macro _CTX_FUNC_DDDD(NAME, FUNCTION)
    quote
        ($NAME)(ctx::CairoContext, d0::Real, d1::Real, d2::Real, d3::Real) =
            ccall(dlsym(_jl_libcairo,$string(FUNCTION)), Void,
                (Ptr{Void},Float64,Float64,Float64,Float64),
                ctx.ptr, d0, d1, d2, d3)
    end
end

@_CTX_FUNC_DDDD set_source_rgba cairo_set_source_rgba

function set_font_face(ctx::CairoContext, name::String)
    ccall(dlsym(_jl_libcairo,:cairo_select_font_face),
        Void, (Ptr{Void},Ptr{Uint8},Int32,Int32), ctx.ptr, cstring(name), 0, 0);
end

function set_string_angle(ctx::CairoContext, angle::Real)
    # TBD
end

function space(ctx::CairoContext, x0::Real, y0::Real, x1::Real, y1::Real)
    #cairo_pdf_suface_set_size()
end

function clear(ctx::CairoContext)
    set_source_rgb(ctx, 1.,1.,1.)
    paint(ctx)
    set_source_rgb(ctx, 0.,0.,0.)
end

function label(ctx::CairoContext, i0::Integer, i1::Integer, s::String)
    ccall(dlsym(_jl_libcairo,:cairo_show_text), Void,
        (Ptr{Void},Ptr{Uint8}), ctx.ptr, cstring(s))
end

function label_width(ctx::CairoContext, s::String)
    extents = zeros(Float64, 6)
    ccall(dlsym(_jl_libcairo,:cairo_text_extents), Void, 
        (Ptr{Void},Ptr{Uint8},Ptr{Float64}), ctx.ptr, cstring(s), extents)
    extents[3]
end

function line(ctx::CairoContext, x0::Real, y0::Real, x1::Real, y1::Real)
    move(ctx, x0, y0)
    lineto(ctx, x1, y1)
    set_source_rgb(ctx, 0., 0., 0.) # wtf?
    stroke(ctx)
end

function end_page(ctx::CairoContext)
end

# -----------------------------------------------------------------------------

function curve(pl::CairoContext, x::Vector, y::Vector)
    n = min(length(x), length(y))
    if n <= 0
        return
    end
 
    new_path(pl)
    move( pl, x[1], y[1] )
    for i = 2:n
        lineto( pl, x[i], y[i] )
    end
    stroke(pl)
end

function clipped_curve(pl::CairoContext, x::Vector, y::Vector, xmin, xmax, ymin, ymax)
    save(pl)
    #clip(pl) # XXX
    curve(pl, x, y)
    restore(pl)
end

type RendererState
    current::HashTable
    saved::Vector{HashTable}

    RendererState() = new(HashTable(),HashTable[])
end

function set( self::RendererState, name, value )
    self.current[name] = value
end

get(self::RendererState, name) = get(self, name, nothing)
function get( self::RendererState, name, notfound )
    if has(self.current, name)
        return self.current[name]
    end
    for d = self.saved
        if has(d,name)
            return d[name]
        end
    end
    return notfound
end

function save( self::RendererState )
    enqueue( self.saved, self.current )
    self.current = HashTable()
end

function restore( self::RendererState )
    self.current = self.saved[1]
    del(self.saved, 1)
end

function color_to_rgb( hextriplet::Integer )
    s = 1. / 0xff
    r = s * ((hextriplet >> 16) & 0xff) 
    g = s * ((hextriplet >>  8) & 0xff)
    b = s * ((hextriplet >>  0) & 0xff)
    return (r, g, b)
end

function color_to_rgb(color::String)
    # XXX:fixme
    if color == "red"
        return (1.,0.,0.)
    elseif color == "blue"
        return (0.,0.,1.)
    end
end

function _set_color( ctx::CairoContext, color )
    println("_set_color ",color)
    (r,g,b) = color_to_rgb( color )
    set_source_rgb( ctx, r, g, b )
end

const _set_fill_color = _set_color
const _set_pen_color = _set_color

function _set_line_type( pl::CairoContext, typ )
    const _pl_line_type = {
       "dot"       => "dotted",
       "dash"      => "shortdashed",
       "dashed"    => "shortdashed",
    }
    pl_type = get(_pl_line_type, typ, typ)
    set_line_type( pl, pl_type )
end

type CairoRenderer <: Renderer
    lowerleft :: (Integer,Integer)
    upperright :: (Integer,Integer)
    ctx :: Union(CairoContext,Nothing)
    surface :: CairoSurface
    state
    bbox
    reuse::Bool

    function CairoRenderer(ll, ur, kind, parameters, fptr)
        width = abs(ur[1] - ll[1])
        height = abs(ur[2] - ll[2])
        surface = CairoRGBSurface(width, height)
        ctx = CairoContext(surface)
        new(ll, ur, ctx, surface, nothing, nothing, false)
    end
    CairoRenderer(ll, ur, kind, parameters) =
        CairoRenderer(ll, ur, kind, parameters, C_NULL)
end

function open( self::CairoRenderer )
    self.state = RendererState()
    #show_page( self.ctx )
    ll = self.lowerleft
    ur = self.upperright
    space( self.ctx, ll[1], ll[2], ur[1], ur[2] )
    clear( self.ctx )
end

function clear( self::CairoRenderer )
    clear( self.ctx )
end

function close( self::CairoRenderer )
    if self.ctx != nothing
        if self.reuse
            flush(self.ctx)
        else
            end_page( self.ctx )
        end
    end
end

function delete( self::CairoRenderer )
    if self.ctx != nothing
        if self.reuse
            flush(self.ctx)
        else
            delete( self.ctx )
            self.ctx = nothing
        end
    end
end

## state commands

__pl_style_func = {
    "color"     => _set_color,
    "linecolor" => _set_pen_color,
    "fillcolor" => _set_fill_color,
    "linetype"  => _set_line_type,
    "linewidth" => set_line_width,
    "filltype"  => set_fill_type,
    "fontface"  => set_font_face,
    "fontsize"  => set_font_size,
    "textangle" => set_string_angle,
}

function set( self::CairoRenderer, key, value )
    set(self.state, key, value )
    if has(__pl_style_func, key)
        __pl_style_func[key](self.ctx, value)
    end
end

function get(self::CairoRenderer, parameter, notfound)
    return get(self.state, parameter, notfound)
end

function get(self::CairoRenderer, parameter)
    get(self, parameter, nothing)
end

function save_state( self::CairoRenderer )
    save(self.state)
    save(self.ctx)
end

function restore_state( self::CairoRenderer )
    restore(self.state)
    restore(self.ctx)
end

## drawing commands

function move(self::CairoRenderer, p)
    move( self.ctx, p[1], p[2] )
end

function lineto( self::CairoRenderer, p )
    lineto( self.ctx, p[1], p[2] )
end

function linetorel( self::CairoRenderer, p )
    linetorel( self.ctx, p[1], p[2] )
end

function line( self::CairoRenderer, p, q )
    cr = get( self, "cliprect" )
    if cr == nothing
        line( self.ctx, p[1], p[2], q[1], q[2] )
    else
        clipped_line( self.ctx, 
            cr[1], cr[2], cr[3], cr[4], 
            p[1], p[2], q[1], q[2] )
    end
end

function rect( self::CairoRenderer, p, q )
    rect( self.ctx, p[1], p[2], q[1], q[2] )
end

function circle( self::CairoRenderer, p, r )
    circle( self.ctx, p[1], p[2], r )
end

function ellipse( self::CairoRenderer, p, rx, ry, angle )
    ellipse( self.ctx, p[1], p[2], rx, ry, angle )
end

function arc( self::CairoRenderer, c, p, q )
    arc( self.ctx, c[1], c[2], p[1], p[2], q[1], q[2] )
end

__pl_symbol_type = {
    "none"              => 0,
    "dot"               => 1,
    "plus"              => 2,
    "asterisk"          => 3,
    "circle"            => 4,
    "cross"             => 5,
    "square"            => 6,
    "triangle"          => 7,
    "diamond"           => 8,
    "star"              => 9,
    "inverted triangle"     => 10,
    "starburst"         => 11,
    "fancy plus"            => 12,
    "fancy cross"           => 13,
    "fancy square"          => 14,
    "fancy diamond"         => 15,
    "filled circle"         => 16,
    "filled square"         => 17,
    "filled triangle"       => 18,
    "filled diamond"        => 19,
    "filled inverted triangle"  => 20,
    "filled fancy square"       => 21,
    "filled fancy diamond"      => 22,
    "half filled circle"        => 23,
    "half filled square"        => 24,
    "half filled triangle"      => 25,
    "half filled diamond"       => 26,
    "half filled inverted triangle" => 27,
    "half filled fancy square"  => 28,
    "half filled fancy diamond" => 29,
    "octagon"           => 30,
    "filled octagon"        => 31,
}

function symbol( self::CairoRenderer, p )
    symbols( self, [p[1]], [p[2]] )
end

function symbols( self::CairoRenderer, x, y )
    DEFAULT_SYMBOL_TYPE = "square"
    DEFAULT_SYMBOL_SIZE = 0.01
    type_str = get(self.state, "symboltype", DEFAULT_SYMBOL_TYPE )
    size = get(self.state, "symbolsize", DEFAULT_SYMBOL_SIZE )
    if strlen(type_str) == 1
        kind = int(type_str[1])
    else
        kind = __pl_symbol_type[type_str]
    end

    cr = get( self, "cliprect" )
    if cr == nothing
        symbols( self.ctx, x, y, kind, size )
    else
        clipped_symbols( self.ctx, x, y, kind, size,
            cr[1], cr[2], cr[3], cr[4] )
    end
end

function curve( self::CairoRenderer, x, y )
    cr = get( self, "cliprect" )
    if cr == nothing
        curve( self.ctx, x, y )
    else
        clipped_curve( self.ctx, x, y,
            cr[1], cr[2], cr[3], cr[4] )
    end
end

function polygon( self::CairoRenderer, points::Vector )
    move(self, points[1])
    for i in 2:length(points)
        lineto(self, points[i])
    end
    close_path(self.ctx)
    fill(self.ctx)
end

# text commands

__pl_text_align = {
   "center"    => int('c'),
   "baseline"  => int('x'),
   "left"      => int('l'),
   "right"     => int('r'),
   "top"       => int('t'),
   "bottom"    => int('b'),
}

function text( self::CairoRenderer, p, str )
    hstr = get( self.state, "texthalign", "center" )
    vstr = get( self.state, "textvalign", "center" )
    hnum = __pl_text_align[hstr]
    vnum = __pl_text_align[vstr]
    move( self.ctx, p[1], p[2] )
    label( self.ctx, hnum, vnum, str )
end

function textwidth( self::CairoRenderer, str )
    return label_width( self.ctx, str )
end

function textheight( self::CairoRenderer, str )
    return get( self.state, "fontsize" ) ## XXX: kludge?
end

function ImageRenderer(kind, width, height, filename)
    ll = (0, 0)
    ur = (width, height)
    parameters = {"BITMAPSIZE" => "$(width)x$(height)"}
    CairoRenderer(ll, ur, kind, parameters, filename)
end

