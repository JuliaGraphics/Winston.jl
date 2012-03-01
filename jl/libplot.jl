#
# Copyright (c) 2012 Mike Nolta <mike@nolta.net>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA  02111-1307, USA.
#

_dl_libplot = dlopen("libplot")

type LibplotPlotter
    plPlotter :: Ptr{Void}

    function LibplotPlotter(kind::String, opts::HashTable, fptr::Ptr{Void})

        params = ccall(dlsym(_dl_libplot,:pl_newplparams), Ptr{Void}, ())

        for (k::String,v::String) = opts
            ccall(dlsym(_dl_libplot,:pl_setplparam), Void,
                (Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}),
                params, cstring(k), cstring(v))
        end

        pl = ccall(dlsym(_dl_libplot,:pl_newpl_r), Ptr{Void},
            (Ptr{Uint8}, Ptr{Void}, Ptr{Void}, Ptr{Void}, Ptr{Void}),
            cstring(kind), C_NULL, fptr, C_NULL, params)

        ccall(dlsym(_dl_libplot,:pl_deleteplparams), Void, (Ptr{Void},), params)
        new(pl)
    end
end

LibplotPlotter(kind, params) = LibplotPlotter(kind, params, C_NULL)
LibplotPlotter(kind) = LibplotPlotter(kind, HashTable{String,String}())
LibplotPlotter() = LibplotPlotter("X")

###############################################################################

macro _PL_FUNC(NAME, FUNCTION)
    quote
        ($NAME)(x::LibplotPlotter) =
            ccall(dlsym(_dl_libplot,$string(FUNCTION)),
                Void, (Ptr{Void},), x.plPlotter)
    end
end

@_PL_FUNC clear pl_erase_r
@_PL_FUNC end_page pl_closepl_r
@_PL_FUNC delete pl_deletepl_r
@_PL_FUNC flush pl_flushpl_r
@_PL_FUNC gsave pl_savestate_r
@_PL_FUNC grestore pl_restorestate_r
@_PL_FUNC begin_page pl_openpl_r
@_PL_FUNC end_path pl_endpath_r

###############################################################################

macro _PL_FUNC_I(NAME, FUNCTION)
    quote
        ($NAME)(x::LibplotPlotter, i::Integer) =
            ccall(dlsym(_dl_libplot,$string(FUNCTION)),
                Void, (Ptr{Void},Int32), x.plPlotter, int32(i))
    end
end

@_PL_FUNC_I set_fill_type pl_filltype_r

###############################################################################

macro _PL_FUNC_D(NAME, FUNCTION)
    quote
        ($NAME)(x::LibplotPlotter, d0::Real) =
            ccall(dlsym(_dl_libplot,$string(FUNCTION)),
                Void, (Ptr{Void},Float64), x.plPlotter, float64(d0))
    end
end

macro _PL_FUNC_DD(NAME, FUNCTION)
    quote
        ($NAME)(x::LibplotPlotter, d0::Real, d1::Real) =
            ccall(dlsym(_dl_libplot,$string(FUNCTION)), Void,
                (Ptr{Void},Float64,Float64),
                x.plPlotter, float64(d0), float64(d1))
    end
end

macro _PL_FUNC_DDD(NAME, FUNCTION)
    quote
        ($NAME)(x::LibplotPlotter, d0::Real, d1::Real, d2::Real) =
            ccall(dlsym(_dl_libplot,$string(FUNCTION)), Void,
                (Ptr{Void},Float64,Float64,Float64),
                x.plPlotter, float64(d0), float64(d1), float64(d2))
    end
end

macro _PL_FUNC_DDDD(NAME, FUNCTION)
    quote
        ($NAME)(x::LibplotPlotter, d0::Real, d1::Real, d2::Real, d3::Real) =
            ccall(dlsym(_dl_libplot,$string(FUNCTION)), Void,
                (Ptr{Void},Float64,Float64,Float64,Float64),
                x.plPlotter, float64(d0), float64(d1), float64(d2), float64(d3))
    end
end

macro _PL_FUNC_DDDDD(NAME, FUNCTION)
    quote
        ($NAME)(x::LibplotPlotter, d0::Real, d1::Real, d2::Real, d3::Real, d4::Real) =
            ccall(dlsym(_dl_libplot,$string(FUNCTION)), Void,
                (Ptr{Void},Float64,Float64,Float64,Float64,Float64),
                x.plPlotter, float64(d0), float64(d1), float64(d2), float64(d3), float64(d4))
    end
end

macro _PL_FUNC_DDDDDD(NAME, FUNCTION)
    quote
        ($NAME)(x::LibplotPlotter, d0::Real, d1::Real, d2::Real, d3::Real, d4::Real, d5::Real) =
            ccall(dlsym(_dl_libplot,$string(FUNCTION)), Void,
                (Ptr{Void},Float64,Float64,Float64,Float64,Float64,Float64),
                x.plPlotter, float64(d0), float64(d1), float64(d2), float64(d3), float64(d4), float64(d5))
    end
end

@_PL_FUNC_D set_font_size pl_ffontsize_r
@_PL_FUNC_D set_line_size pl_flinewidth_r
@_PL_FUNC_D set_string_angle pl_ftextangle_r

@_PL_FUNC_DD move pl_fmove_r
@_PL_FUNC_DD lineto pl_fcont_r
@_PL_FUNC_DD linetorel pl_fcontrel_r

@_PL_FUNC_DDD circle pl_fcircle_r

@_PL_FUNC_DDDD line pl_fline_r
@_PL_FUNC_DDDD rect pl_fbox_r
@_PL_FUNC_DDDD space pl_fspace_r

@_PL_FUNC_DDDDD ellipse pl_fellipse_r

@_PL_FUNC_DDDDDD arc pl_farc_r

function marker(x::LibplotPlotter, d0::Real, d1::Real, i0::Integer, d3::Real)
    ccall(dlsym(_dl_libplot,:pl_fmarker_r), Void,
        (Ptr{Void},Float64,Float64,Int32,Float64),
        x.plPlotter, float64(d0), float64(d1), int32(i0), float64(d3))
end

###############################################################################

macro _PL_FUNC_S(NAME, FUNCTION)
    quote
        ($NAME)(x::LibplotPlotter, s::String) =
            ccall(dlsym(_dl_libplot,$string(FUNCTION)),
                Void, (Ptr{Void},Ptr{Uint8}), x.plPlotter, cstring(s))
    end
end

@_PL_FUNC_S set_colorname_bg pl_bgcolorname_r
@_PL_FUNC_S set_colorname_fg pl_colorname_r
@_PL_FUNC_S set_colorname_fill pl_fillcolorname_r
@_PL_FUNC_S set_colorname_pen pl_pencolorname_r

@_PL_FUNC_S set_fill_mode pl_fillmod_r
@_PL_FUNC_S set_font_type pl_fontname_r
@_PL_FUNC_S set_join_type pl_joinmod_r
@_PL_FUNC_S set_line_type pl_linemod_r

###############################################################################
#  color functions

macro _PL_FUNC_COLOR(NAME, FUNCTION)
    quote
        function ($NAME)(x::LibplotPlotter, dr::Float64, dg::Float64, db::Float64)
            r = int32(floor(dr*65535))
            g = int32(floor(dg*65535))
            b = int32(floor(db*65535))
            ccall(dlsym(_dl_libplot,$string(FUNCTION)),
                Void, (Ptr{Void},Int32,Int32,Int32), x.plPlotter, r, g, b)
        end
    end
end

@_PL_FUNC_COLOR set_color_bg pl_bgcolor_r
@_PL_FUNC_COLOR set_color_fg pl_color_r
@_PL_FUNC_COLOR set_color_fill pl_fillcolor_r
@_PL_FUNC_COLOR set_color_pen pl_pencolor_r

###############################################################################

let
    const TOP = 0x1
    const BOTTOM = 0x2
    const RIGHT = 0x4
    const LEFT = 0x8

    function outcode(x::Float64::Float64, y::Float64,
        xmin::Float64, xmax::Float64, ymin::Float64, ymax::Float64)

        code = 0x0
        if x < xmin
            code |= LEFT
        end
        if x > xmax
            code |= RIGHT
        end
        if y < ymin
            code |= BOTTOM
        end
        if y > ymax
            code |= TOP
        end
        return code
    end
    
    function cohen_sutherland(xmin::Float64, xmax::Float64, ymin::Float64, ymax::Float64,
        x0::Float64, y0::Float64, x1::Float64, y1::Float64)

        x = 0.
        y = 0.

        out0 = outcode( x0, y0, xmin, xmax, ymin, ymax )
        out1 = outcode( x1, y1, xmin, xmax, ymin, ymax )

        accept = false
        done = false

        while !done

            if (out0 == 0) && (out1 == 0)
                # trivially inside
                accept = true
                done = true
            elseif (out0 & out1) != 0
                # trivially outside
                done = true
            else
                out = ( out0 != 0 ) ? out0 : out1

                if (out & TOP) != 0
                    x = x0 + (x1 - x0)*(ymax - y0)/(y1 - y0)
                    y = ymax
                elseif (out & BOTTOM) != 0
                    x = x0 + (x1 - x0)*(ymin - y0)/(y1 - y0)
                    y = ymin
                elseif (out & RIGHT) != 0
                    y = y0 + (y1 - y0)*(xmax - x0)/(x1 - x0)
                    x = xmax
                elseif (out & LEFT) != 0
                    y = y0 + (y1 - y0)*(xmin - x0)/(x1 - x0)
                    x = xmin
                end

                if out == out0
                    x0 = x
                    y0 = y
                    out0 = outcode( x, y, xmin, xmax, ymin, ymax ) 
                else
                    x1 = x
                    y1 = y
                    out1 = outcode( x, y, xmin, xmax, ymin, ymax )
                end
            end
        end

        return (accept,(x0,y0,x1,y1))
    end

    global clipped_line
    function clipped_line(pl::LibplotPlotter,
        xmin::Float64, xmax::Float64, ymin::Float64, ymax::Float64,
        x0::Float64, y0::Float64, x1::Float64, y1::Float64)

        (accept,coords) = cohen_sutherland( xmin, xmax, ymin, ymax, x0, y0, x1, y1)
        if accept
            (xc0, yc0, xc1, yc1) = coords
            line(pl, xc0, yc0, xc1, yc1 )
        end
    end
end

###############################################################################

function label(x::LibplotPlotter, i0::Integer, i1::Integer, s::String)
    ccall(dlsym(_dl_libplot,:pl_alabel_r), Void,
        (Ptr{Void},Int32,Int32,Ptr{Uint8}),
        x.plPlotter, int32(i0), int32(i1), cstring(s))
end

function label_width(x::LibplotPlotter, s::String)
    ccall(dlsym(_dl_libplot,:pl_flabelwidth_r), Float64,
        (Ptr{Void},Ptr{Uint8}), x.plPlotter, cstring(s))
end

###############################################################################
# symbol routines

let
    function _symbol_begin(pl::LibplotPlotter, t::Integer, size::Float64)
        if t > 31
            gsave(pl)
            set_font_size(pl, size)
        end
    end

    function _symbol_draw(pl::LibplotPlotter, x::Float64, y::Float64, t::Integer, size::Float64)
        if t > 31
            move(pl, x, y)
            label(pl, 'c', 'c', string(char(t)))
        else
            marker( pl, x, y, t, size )
        end
    end

    function _symbol_end(x::LibplotPlotter, t::Integer)
        if t > 31
            grestore(x)
        end
    end

    global symbols
    function symbols(pl::LibplotPlotter, x::Vector, y::Vector, i0, d0)
        n = min(numel(x), numel(y))
        _symbol_begin(pl, i0, d0)
        for i = 1:n
            _symbol_draw(pl, x[i], y[i], i0, d0)
        end
        _symbol_end(pl, i0)
    end

    global clipped_symbols
    function clipped_symbols(pl::LibplotPlotter, x::Vector, y::Vector,
            i0, d0, xmin, xmax, ymin, ymax)
        n = min(numel(x), numel(y))
        _symbol_begin( pl, i0, d0 )
        for i = 1:n
            px = x[i]
            py = y[i]
            if px >= xmin && px <= xmax &&
                 py >= ymin && py <= ymax
                _symbol_draw( pl, px, py, i0, d0 )
            end
        end
        _symbol_end(pl, i0)
    end

    global clipped_colored_symbols
    function clipped_colored_symbols(pl::LibplotPlotter,
        x::Vector, y::Vector, c::Matrix, i0, d0, xmin, xmax, ymin, ymax)
     
        n = min(length(x), length(y), length(c))
        _symbol_begin( pl, i0, d0 )

        for i = 1:n
            px = x[i]
            py = y[i]
     
            if px >= xmin && px <= xmax && py >= ymin && py <= ymax
                r = int(floor(c[i,1]*65535))
                g = int(floor(c[i,2]*65535))
                b = int(floor(c[i,3]*65535))
                set_color_fill(pl, r, g, b)
                set_color_pen(pl, r, g, b)
                _symbol_draw( pl, px, py, i0, d0 )
            end
        end
     
        _symbol_end( pl, i0 )
    end
end

function curve(pl::LibplotPlotter, x::Vector, y::Vector)
    n = min(length(x), length(y))
    if n <= 0
        return
    end
 
    move( pl, x[1], y[1] )
    for i = 2:n
        lineto( pl, x[i], y[i] )
    end
    end_path(pl)
end

function clipped_curve(pl::LibplotPlotter, x::Vector, y::Vector, xmin, xmax, ymin, ymax)
    n = min(length(x), length(y))
    if n == 0
        return
    end
    for i = 1:n-1
        clipped_line( pl, xmin, xmax, ymin, ymax,
            x[i], y[i], x[i+1], y[i+1] )
    end 
    end_path(pl)
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

function _hexcolor( hextriplet::Number )
    _hexcolor(hextriplet, 1)
end

function _hexcolor( hextriplet::Number, scale::Number )
    s = float(scale) / 0xff
    r = s * ((hextriplet >> 16) & 0xff) 
    g = s * ((hextriplet >>  8) & 0xff)
    b = s * ((hextriplet >>  0) & 0xff)
    return (r, g, b)
end

function _set_color( pl::LibplotPlotter, color )
    if typeof(color) <: String
        set_colorname_fg( pl, color )
    else
        (r,g,b) = _hexcolor( color )
        set_color_fg( pl, r, g, b )
    end
end

function _set_pen_color( pl::LibplotPlotter, color )
    if typeof(color) <: String
        set_colorname_pen( pl, color )
    else
        (r,g,b) = _hexcolor( color )
        set_color_pen( pl, r, g, b )
    end
end

function _set_fill_color( pl::LibplotPlotter, color )
    if typeof(color) <: String
        set_colorname_fill( pl, color )
    else
        (r,g,b) = _hexcolor( color )
        set_color_fill( pl, r, g, b )
    end
end

function _set_line_type( pl::LibplotPlotter, typ )
    const _pl_line_type = {
       "dot"       => "dotted",
       "dash"      => "shortdashed",
       "dashed"    => "shortdashed",
    }
    pl_type = get(_pl_line_type, typ, typ)
    set_line_type( pl, pl_type )
end

abstract Renderer

type LibplotRenderer <: Renderer
    lowerleft :: (Integer,Integer)
    upperright :: (Integer,Integer)
    pl :: Union(LibplotPlotter,Nothing)
    state
    bbox
    reuse::Bool

    function LibplotRenderer(ll, ur, kind, parameters, fptr)
        pl = LibplotPlotter(kind, parameters, fptr)
        new(ll, ur, pl, nothing, nothing, false)
    end
    LibplotRenderer(ll, ur, kind, parameters) =
        LibplotRenderer(ll, ur, kind, parameters, C_NULL)
end

function open( self )
    self.state = RendererState()
    begin_page( self.pl )
    ll = self.lowerleft
    ur = self.upperright
    space( self.pl, ll[1], ll[2], ur[1], ur[2] )
    clear( self.pl )
end

function clear( self )
    clear( self.pl )
end

function close( self )
    if self.pl != nothing
        if self.reuse
            flush(self.pl)
        else
            end_page( self.pl )
        end
    end
end

function delete( self )
    if self.pl != nothing
        if self.reuse
            flush(self.pl)
        else
            delete( self.pl )
            self.pl = nothing
        end
    end
end

## state commands

__pl_style_func = {
    "color"     => _set_color,
    "linecolor" => _set_pen_color,
    "fillcolor" => _set_fill_color,
    "linetype"  => _set_line_type,
    "linewidth" => set_line_size,
    "filltype"  => set_fill_type,
    "fillmode"  => set_fill_mode,
    "fontface"  => set_font_type,
    "fontsize"  => set_font_size,
    "textangle" => set_string_angle,
}

function set( self::LibplotRenderer, key, value )
    set(self.state, key, value )
    if has(__pl_style_func, key)
        #show(key)
        #show(value)
        __pl_style_func[key](self.pl, value)
    end
end

function get(self::LibplotRenderer, parameter, notfound)
    return get(self.state, parameter, notfound)
end

function get(self::LibplotRenderer, parameter)
    get(self, parameter, nothing)
end

function save_state( self::LibplotRenderer )
    save(self.state)
    gsave(self.pl)
end

function restore_state( self::LibplotRenderer )
    restore(self.state)
    grestore(self.pl)
end

## drawing commands

function move(self::LibplotRenderer, p)
    move( self.pl, p[1], p[2] )
end

function lineto( self::LibplotRenderer, p )
    lineto( self.pl, p[1], p[2] )
end

function linetorel( self::LibplotRenderer, p )
    linetorel( self.pl, p[1], p[2] )
end

function line( self::LibplotRenderer, p, q )
    cr = get( self, "cliprect" )
    if cr == nothing
        line( self.pl, p[1], p[2], q[1], q[2] )
    else
        clipped_line( self.pl, 
            cr[1], cr[2], cr[3], cr[4], 
            p[1], p[2], q[1], q[2] )
    end
end

function rect( self::LibplotRenderer, p, q )
    rect( self.pl, p[1], p[2], q[1], q[2] )
end

function circle( self::LibplotRenderer, p, r )
    circle( self.pl, p[1], p[2], r )
end

function ellipse( self::LibplotRenderer, p, rx, ry, angle )
    ellipse( self.pl, p[1], p[2], rx, ry, angle )
end

function arc( self::LibplotRenderer, c, p, q )
    arc( self.pl, c[1], c[2], p[1], p[2], q[1], q[2] )
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

function symbol( self::LibplotRenderer, p )
    symbols( self, [p[1]], [p[2]] )
end

function symbols( self::LibplotRenderer, x, y )
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
        symbols( self.pl, x, y, kind, size )
    else
        clipped_symbols( self.pl, x, y, kind, size,
            cr[1], cr[2], cr[3], cr[4] )
    end
end

function curve( self::LibplotRenderer, x, y )
    cr = get( self, "cliprect" )
    if cr == nothing
        curve( self.pl, x, y )
    else
        clipped_curve( self.pl, x, y,
            cr[1], cr[2], cr[3], cr[4] )
    end
end

let
    function sh_inside( p, dim, boundary, side )
        side*p[dim] >= side*boundary
    end

    function sh_intersection( s, p, dim, boundary )
        mid = (dim == 1) ? 2 : 1
        g = 0.
        if p[dim] != s[dim]
            g = (boundary - s[dim])/(p[dim] - s[dim])
        end
        q = [0,0]
        q[dim] = boundary
        q[mid] = s[mid] + g*(p[mid] - s[mid])
        return q[1], q[2]
    end

    function sutherland_hodgman( polygon, dim, boundary, side )
        out = {}
        s = polygon[end]
        s_inside = sh_inside( s, dim, boundary, side )
        for p = polygon
            p_inside = sh_inside( p, dim, boundary, side )

            if (p_inside && !s_inside) || (!p_inside && s_inside)
                push( out, sh_intersection(s, p, dim, boundary) )
            end

            if p_inside
                push(out, p )
            end

            s = p
            s_inside = p_inside
        end

        return out
    end

    global polygon
    function polygon( self::LibplotRenderer, points::Vector )
        pts = copy(points)
        cr = get(self, "cliprect")
        if cr != nothing
            pts = sutherland_hodgman( pts, 1, cr[1], +1 )
            pts = sutherland_hodgman( pts, 1, cr[2], -1 )
            pts = sutherland_hodgman( pts, 2, cr[3], +1 )
            pts = sutherland_hodgman( pts, 2, cr[4], -1 )
        end
        move(self, pts[1])
        for i in 2:length(pts)
            lineto(self, pts[i])
        end
    end
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

function text( self::LibplotRenderer, p, str )
    plstr = tex2libplot( str )
    hstr = get( self.state, "texthalign", "center" )
    vstr = get( self.state, "textvalign", "center" )
    hnum = __pl_text_align[hstr]
    vnum = __pl_text_align[vstr]
    move( self.pl, p[1], p[2] )
    label( self.pl, hnum, vnum, plstr )
end

function textwidth( self::LibplotRenderer, str )
    plstr = tex2libplot( str )
    return label_width( self.pl, plstr )
end

function textheight( self::LibplotRenderer, str )
    return get( self.state, "fontsize" ) ## XXX: kludge?
end

function NonReusableScreenRenderer(width::Integer, height::Integer)
    ll = (0, 0)
    ur = (width, height)
    parameters = {
        "BITMAPSIZE" => "$(width)x$(height)",
        "VANISH_ON_DELETE" => "no",
    }
    LibplotRenderer(ll, ur, "X", parameters)
end

function ReusableScreenRenderer( width::Integer, height::Integer )
    ll = (0, 0)
    ur = (width, height)
    parameters = {
        "BITMAPSIZE" => "$(width)x$(height)",
        "VANISH_ON_DELETE" => "yes",
    }
    LibplotRenderer( ll, ur, "X", parameters )
 
# XXX:incorporate into close/delete funcs
#
#   function close( self )
#       flush( self.pl )
#
#   function delete( self )
#       flush( self.pl )
end

_saved_screen_renderer = nothing

function ScreenRenderer( reuse::Bool, width::Integer, height::Integer )
    if reuse
        global _saved_screen_renderer
        if _saved_screen_renderer == nothing
            _saved_screen_renderer = ReusableScreenRenderer( width, height )
            _saved_screen_renderer.reuse = true
        end
        clear(_saved_screen_renderer)
        return _saved_screen_renderer
    else
        return NonReusableScreenRenderer( width, height )
    end
end

function _str_size_to_pts( str )
    m = match(r"([\d.]+)([^\s]+)", str)
    num_xx = float(m.captures[1])
    units = m.captures[2]
    # convert to postscipt pt = in/72
    xx2pt = { "in"=>72., "pt"=>1., "mm"=>2.835, "cm"=>28.35 }
    num_pt = int(num_xx*xx2pt[units])
    return num_pt
end

PSRenderer(fptr::Ptr{Void}) = PSRenderer(fptr, HashTable())
function PSRenderer(fptr::Ptr{Void}, opt::HashTable)
    paper = opt["paper"]
    width = opt["width"]
    height = opt["height"]
    ll = (0, 0)
    ur = (_str_size_to_pts(width), _str_size_to_pts(height))
    pagesize = "$paper,xsize=$width,ysize=$height"
    parameters = { "PAGESIZE" => pagesize }
    LibplotRenderer(ll, ur, "ps", parameters, fptr)
end

function ImageRenderer(kind, width, height, file)
    ll = (0, 0)
    ur = (width, height)
    parameters = {"BITMAPSIZE" => "$(width)x$(height)"}
    LibplotRenderer(ll, ur, kind, parameters, file)
end

#
# Convert simple TeX strings to Hershey font strings.
#

type TeXLexer
    str::String
    len::Integer
    pos::Integer
    token_stack::Array{String,1}
    re_control_sequence::Regex

    function TeXLexer( str::String )
        self = new()
        self.str = str
        self.len = strlen(str)
        self.pos = 1
        self.token_stack = String[]
        self.re_control_sequence = r"^\\[a-zA-Z]+[ ]?|^\\[^a-zA-Z][ ]?"
        self
    end
end

function get_token( self::TeXLexer )
    if self.pos == self.len+1
        return nothing
    end

    if length(self.token_stack) > 0
        return pop(self.token_stack)
    end

    str = self.str[self.pos:end]
    m = match(self.re_control_sequence, str)
    if m != nothing
        token = m.match
        self.pos = self.pos + strlen(token)
        # consume trailing space
        if strlen(token) > 2 && token[end] == ' '
            token = token[1:end-1]
        end
    else
        token = str[1:1]
        self.pos = self.pos + 1
    end

    return token
end

function put_token( self::TeXLexer, token )
    push( self.token_stack, token )
end

function peek( self::TeXLexer )
    token = get_token(self)
    put_token( self, token )
    return token
end

_common_token_dict = {
    L"\\"               => "\\",
    L"\$"               => L"$",
    L"\%"               => L"%",
    L"\#"               => L"#",
    L"\&"               => L"&",
#   L"\~"               => L"~",
    L"\{"               => L"{",
    L"\}"               => L"}",
    L"\_"               => L"_",
#   L"\^"               => L"^",

    L"~"                => L" ",
    L"\/"               => L"\r^",

    ## special letters (p52)
#   L"\oe"              => L"",
#   L"\OE"              => L"",
    L"\ae"              => L"\ae",
    L"\AE"              => L"\AE",
    L"\aa"              => L"\oa",
    L"\AA"              => L"\oA",
    L"\o"               => L"\/o",
    L"\O"               => L"\/O",
#   L"\l"               => L"",
#   L"\L"               => L"",
    L"\ss"              => L"\ss",

    ## ignore stray brackets
    L"{"                => L"",
    L"}"                => L"",
}

_text_token_dict = {
    ## punctuation (p52)
    L"\`"               => L"\`",
    r"\""               => r"\"",
    L"\^"               => L"\^",
    L"\""               => L"\:",
    L"\~"               => L"\~",
    L"\c"               => L"\,",

    ## non-math symbols (p438)
    L"\S"               => L"\sc",
    L"\P"               => L"\ps",
    L"\dag"             => L"\dg",
    L"\ddag"            => L"\dd",
}

_math_token_dict = {

    L"*"                => L"\**",

    ## spacing
#   L" "                => L"",
    L"\ "               => L" ",
    L"\quad"            => L"\r1",   # 1 em
    L"\qquad"           => L"\r1\r1",    # 2 em
    L"\,"               => L"\r6",   # 3/18 em
#   L"\>"               => L"",      # 4/18 em
#   L"\;"               => L"",      # 5/18 em
    L"\!"               => L"\l6",   # -1/6 em

    ## lowercase greek
    L"\alpha"           => L"\*a",
    L"\beta"            => L"\*b",
    L"\gamma"           => L"\*g",
    L"\delta"           => L"\*d",
    L"\epsilon"         => L"\*e",
#   L"\varepsilon"      => L"",
    L"\zeta"            => L"\*z",
    L"\eta"             => L"\*y",
    L"\theta"           => L"\*h",
    L"\vartheta"        => L"\+h",
    L"\iota"            => L"\*i",
    L"\kappa"           => L"\*k",
    L"\lambda"          => L"\*l",
    L"\mu"              => L"\*m",
    L"\nu"              => L"\*n",
    L"\xi"              => L"\*c",
    L"\pi"              => L"\*p",
#   L"\varpi"           => L"",
    L"\rho"             => L"\*L",
#   L"\varrho"          => L"",
    L"\sigma"           => L"\*s",
    L"\varsigma"        => L"\ts",
    L"\tau"             => L"\*t",
    L"\upsilon"         => L"\*u",
    L"\phi"             => L"\*f",
    L"\varphi"          => L"\+f",
    L"\chi"             => L"\*x",
    L"\psi"             => L"\*q",
    L"\omega"           => L"\*w",

    ## uppercase greek
    L"\Alpha"           => L"\*A",
    L"\Beta"            => L"\*B",
    L"\Gamma"           => L"\*G",
    L"\Delta"           => L"\*D",
    L"\Epsilon"         => L"\*E",
    L"\Zeta"            => L"\*Z",
    L"\Eta"             => L"\*Y",
    L"\Theta"           => L"\*H",
    L"\Iota"            => L"\*I",
    L"\Kappa"           => L"\*K",
    L"\Lambda"          => L"\*L",
    L"\Mu"              => L"\*M",
    L"\Nu"              => L"\*N",
    L"\Xi"              => L"\*C",
    L"\Pi"              => L"\*P",
    L"\Rho"             => L"\*R",
    L"\Sigma"           => L"\*S",
    L"\Tau"             => L"\*T",
    L"\Upsilon"         => L"\*U",
    L"\Phi"             => L"\*F",
    L"\Chi"             => L"\*X",
    L"\Psi"             => L"\*Q",
    L"\Omega"           => L"\*W",

    ## miscellaneous
    L"\aleph"           => L"\Ah",
    L"\hbaL"            => L"\hb",
    L"\ell"             => L"\#H0662",
    L"\wp"              => L"\wp",
    L"\Re"              => L"\Re",
    L"\Im"              => L"\Im",
    L"\partial"         => L"\pd",
    L"\infty"           => L"\if",
    L"\prime"           => L"\fm",
    L"\emptyset"        => L"\es",
    L"\nabla"           => L"\gL",
    L"\surd"            => L"\sL",
#   L"\top"             => L"",
#   L"\bot"             => L"",
    L"\|"               => L"\||",
    L"\angle"           => L"\/_",
#   L"\triangle"        => L"",
    L"\backslash"       => L"\\",
    L"\forall"          => L"\fa",
    L"\exists"          => L"\te",
    L"\neg"             => L"\no",
#   L"\flat"            => L"",
#   L"\natural"         => L"",
#   L"\sharp"           => L"",
    L"\clubsuit"        => L"\CL",
    L"\diamondsuit"     => L"\DI",
    L"\heartsuit"       => L"\HE",
    L"\spadesuit"       => L"\SP",

    ## binary operations
    L"\pm"              => L"\+-",
    L"\mp"              => L"\-+",
#   L"\setminus"        => L"",
    L"\cdot"            => L"\md",
    L"\times"           => L"\mu",
    L"\ast"             => L"\**",
#   L"\staL"            => L"",
#   L"\diamond"         => L"",
#   L"\circ"            => L"",
    L"\bullet"          => L"\bu",
    L"\div"             => L"\di",
    L"\cap"             => L"\ca",
    L"\cup"             => L"\cu",
#   L"\uplus"           => L"",
#   L"\sqcap"           => L"",
#   L"\sqcup"           => L"",
#   L"\triangleleft"    => L"",
#   L"\triangleright"   => L"",
#   L"\wL"              => L"",
#   L"\bigcirc"         => L"",
#   L"\bigtriangleup"   => L"",
#   L"\bigtriangledown" => L"",
#   L"\vee"             => L"",
#   L"\wedge"           => L"",
    L"\oplus"           => L"\c+",
#   L"\ominus"          => L"",
    L"\otimes"          => L"\c*",
#   L"\oslash"          => L"",
#   L"\odot"            => L"",
    L"\daggeL"          => L"\dg",
    L"\ddaggeL"         => L"\dd",
#   L"\amalg"           => L"",

    ## relations
    L"\leq"             => L"\<=",
#   L"\prec"            => L"",
#   L"\preceq"          => L"",
    L"\ll"              => L"<<",
    L"\subset"          => L"\SB",
#   L"\subseteq"        => L"",
#   L"\sqsubseteq"      => L"",
    L"\in"              => L"\mo",
#   L"\vdash"           => L"",
#   L"\smile"           => L"",
#   L"\frown"           => L"",
    L"\geq"             => L"\>=",
#   L"\succ"            => L"",
#   L"\succeq"          => L"",
    L"\gg"              => L">>",
    L"\supset"          => L"\SS",
#   L"\supseteq"        => L"",
#   L"\sqsupseteq"      => L"",
#   L"\ni"              => L"",
#   L"\dashv"           => L"",
    L"\mid"             => L"|",
    L"\parallel"        => L"\||",
    L"\equiv"           => L"\==",
    L"\sim"             => L"\ap",
    L"\simeq"           => L"\~-",
#   L"\asymp"           => L"",
    L"\approx"          => L"\~~",
    L"\cong"            => L"\=~",
#   L"\bowtie"          => L"",
    L"\propto"          => L"\pt",
#   L"\models"          => L"",
#   L"\doteq"           => L"",
    L"\perp"            => L"\pp",

    ## arrows
    L"\leftarrow"       => L"\<-",
    L"\Leftarrow"       => L"\lA",
    L"\rightarrow"      => L"\->",
    L"\Rightarrow"      => L"\rA",
    L"\leftrightarrow"  => L"\<>",
    L"\Leftrightarrow"  => L"\hA",
#   L"\mapsto"          => L"",
#   L"\hookleftarrow"   => L"",
#   L"\leftharpoonup"   => L"",
#   L"\leftharpoondown" => L"",
#   L"\rightleftharpoons" => L"",
#   ...
    L"\uparrow"         => L"\ua",
    L"\Uparrow"         => L"\uA",
    L"\downarrow"       => L"\da",
    L"\Downarrow"       => L"\dA",
#   L"\updownarrow"     => L"",
#   L"\Updownarrow"     => L"",
#   L"\nearrow"         => L"",
#   L"\searrow"         => L"",
#   L"\swarrow"         => L"",
#   L"\nwarrow"         => L"",

    ## openings
    L"\lbrack"          => L"[",
    L"\lbrace"          => L"{",
    L"\langle"          => L"\la",
#   L"\lflooL"          => L"",
#   L"\lceil"           => L"",

    ## closings
    L"\rbrack"          => L"]",
    L"\rbrace"          => L"}",
    L"\rangle"          => L"\ra",
#   L"\rflooL"          => L"",
#   L"\rceil"           => L"",

    ## alternate names
    L"\ne"              => L"\!=",
    L"\neq"             => L"\!=",
    L"\le"              => L"\<=",
    L"\ge"              => L"\>=",
    L"\to"              => L"\->",
    L"\gets"            => L"\<-",
#   L"\owns"            => L"",
    L"\land"            => L"\AN",
    L"\loL"             => L"\OR",
    L"\lnot"            => L"\no",
    L"\vert"            => L"|",
    L"\Vert"            => L"\||",

    ## extensions
    L"\degrees"         => L"\de",
    L"\degree"          => L"\de",
    L"\deg"             => L"\de",
    L"\degL"            => L"\de",
    L"\arcdeg"          => L"\de",
}

function map_text_token( token )
    if has(_text_token_dict, token)
        return _text_token_dict[token]
    else
        return get(_common_token_dict, token, token )
    end
end

function map_math_token( token )
    if has(_math_token_dict, token)
        return _math_token_dict[token]
    else
        return get(_common_token_dict, token, token )
    end
end

function math_group( lexer::TeXLexer )
    output = ""
    bracketmode = false
    while true
        token = get_token(lexer)
        if token == nothing
            break
        end

        if token == L"{"
            bracketmode = true
        elseif token == L"}"
            break
        else
            output = strcat(output, map_math_token(token))
            if !bracketmode
                break
            end
        end
    end
    return output
end

font_code = [ L"\f0", L"\f1", L"\f2", L"\f3" ]

function tex2libplot( str::String )
    output = ""
    mathmode = false
    font_stack = {}
    font = 1

    lexer = TeXLexer( str )
    while true
        token = get_token(lexer)
        if token == nothing
            break
        end

        more_output = ""

        if token == L"$"
            mathmode = !mathmode
        elseif token == L"{"
            push( font_stack, font )
        elseif token == L"}"
            old_font = pop(font_stack)
            if old_font != font
                font = old_font
                more_output = font_code[font]
            end
        elseif token == L"\rm"
            font = 1
            more_output = font_code[font]
        elseif token == L"\it"
            font = 2
            more_output = font_code[font]
        elseif token == L"\bf"
            font = 3
            more_output = font_code[font]
        elseif !mathmode
            more_output = map_text_token( token )
        elseif token == L"_"
            more_output = strcat(L"\sb", math_group(lexer), L"\eb")
            if peek(lexer) == L"^"
                more_output = strcat(L"\mk", more_output, L"\rt")
            end
        elseif token == L"^"
            more_output = strcat(L"\sp", math_group(lexer), L"\ep")
            if peek(lexer) == L"_"
                more_output = strcat(L"\mk", more_output, L"\rt")
            end
        else
            more_output = map_math_token( token )
        end

        output = strcat(output, more_output)
    end

    return output
end
