
abstract Canvas2D
abstract Renderer

_jl_libcairo = dlopen("libcairo")

type CairoSurface
    ptr::Ptr{Void}

    function CairoSurface(ptr::Ptr{Void})
        self = new(ptr)
        finalizer(self, destroy)
        self
    end
end

function destroy(surface::CairoSurface)
    ccall(dlsym(_jl_libcairo,:cairo_surface_destroy),
        Void, (Ptr{Void},), surface.ptr)
end

function CairoImageSurface(w::Integer, h::Integer)
    ptr = ccall(dlsym(_jl_libcairo,:cairo_image_surface_create),
        Ptr{Void}, (Int32,Int32,Int32), 0, w, h)
    CairoSurface(ptr)
end

type CairoContext <: Canvas2D
    ptr::Ptr{Void}

    function CairoContext(surface::CairoSurface)
        ptr = ccall(dlsym(_jl_libcairo,:cairo_create),
            Ptr{Void}, (Ptr{Void},), surface.ptr)
        self = new(ptr)
        finalizer(self, destroy)
        self
    end
end

function destroy(ctx::CairoContext)
    ccall(dlsym(_jl_libcairo,:cairo_destroy), Void, (Ptr{Void},), ctx.ptr)
end

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

# -----------------------------------------------------------------------------



