module Plot3d

import Winston.output_surface
if output_surface == :tk
    eval(Expr(:toplevel, Expr(:using, :Tk)))
elseif output_surface == :gtk
    eval(Expr(:toplevel, Expr(:using, :Gtk)))
end
using Compat
using Colors
using Graphics

export plot3d, surf
#export demo_sombrero, demo_sphere

mutable struct Canvas3D
    win::Canvas
    ctm::Matrix{Float64}
    sctm::Matrix{Float64}
    lastx::Int
    lasty::Int
    GW::Float64
    GH::Float64
    scalem::Vector{Float64}
    boxv::Matrix{Float64}
    center::Vector{Float64}
    wincenter::Vector{Float64}
    xmin::Float64
    xmax::Float64
    ymin::Float64
    ymax::Float64
    zmin::Float64
    zmax::Float64
    colorbg::RGB
    colorcube::RGB
    models_motion::Vector{Any}
    models_release::Vector{Any}

    function Canvas3D(win; xmin=0, xmax=width(win)-1, ymin=0, ymax=height(win)-1,
                      zmin=-10, zmax=10, colorbg=RGB(1,1,1), colorcube=RGB(0,0,0))
        this = new(win)
        this.xmin = xmin; this.xmax = xmax
        this.ymin = ymin; this.ymax = ymax
        this.zmin = zmin; this.zmax = zmax
        this.ctm = eye(3)
        this.colorbg = colorbg
        this.colorcube = colorcube
        this.models_motion = Any[]
        this.models_release = Any[]

        win.mouse.button1press = (c,x,y)->canvas3d_mousedown(this,x,y)
        win.mouse.button1motion = (c,x,y)->canvas3d_button1motion(this,x,y)
        win.mouse.button1release = (c,x,y)->canvas3d_button1release(this,x,y)
        win.resize = w->configure(this)
        win.draw = c->draw(getgc(this.win), this, false)
        this
    end
end

Base.show(io::IO, c3::Canvas3D) = print(io, "Canvas3D")

cube_verts(x0, x1, y0, y1, z0, z1) = [x0 x1 x1 x0 x0 x1 x1 x0
                                      y0 y0 y1 y1 y0 y0 y1 y1
                                      z0 z0 z0 z0 z1 z1 z1 z1]

function configure(this::Canvas3D)
    WW, WH = width(this.win), height(this.win)
    scalem = [ 0.5774 * WW/(this.xmax - this.xmin),
              -0.5774 * WH/(this.ymax - this.ymin),
               0.5774 * WW/(this.xmax - this.xmin)]
    this.scalem = scalem
    this.sctm = scale(this.ctm, scalem)

    this.center = [(this.xmax+this.xmin)/2,
                   (this.ymax+this.ymin)/2,
                   (this.zmax+this.zmin)/2]
    this.boxv = cube_verts(this.xmin, this.xmax, this.ymin, this.ymax,
                           this.zmin, this.zmax)
    this.GW = WW/2
    this.GH = WH/2
    this.wincenter = [this.GW, this.GH, 0]
    this
end

function project(this::Canvas3D, v::AbstractVector)
    this.sctm * (v-this.center) + this.wincenter
end

function project(this::Canvas3D, v::AbstractMatrix)
    broadcast(+, this.sctm * broadcast(-,v,this.center), this.wincenter)
end

const cube4sides = [[1,5,6,2], [2,6,7,3], [3,7,8,4], [4,8,5,1]]

function draw(gc, this::Canvas3D, motion::Bool)
    bv = similar(this.boxv)
    for i=1:size(bv,2)
        bv[:,i] = project(this, this.boxv[:,i])
    end

    edges = sort(cube4sides, by=p->mean(bv[3,:][p]))

    set_source(gc, this.colorbg)
    paint(gc)

    set_source(gc, this.colorcube)
    set_line_width(gc, 0.6)

    polygon(gc, bv, edges[1])
    polygon(gc, bv, edges[2])
    stroke(gc)

    # draw contents here
    if motion
        for m in this.models_motion
            draw(gc, this, m)
        end
    else
        for m in this.models_release
            draw(gc, this, m)
        end
    end

    polygon(gc, bv, edges[3])
    polygon(gc, bv, edges[4])
    stroke(gc)
end

function canvas3d_mousedown(this::Canvas3D, x, y)
    this.lastx = x
    this.lasty = y
end

# construct a rotation by φ around the given vector
function rotation(x,y,z,φ)
    a = 0.5φ
    s = sin(a)/sqrt(x*x+y*y+z*z)
    cos(a), [x*s, y*s, z*s]
end

# apply quaternion to vector
qrotate(w, qv, v) = v - 2*cross(cross(qv, v) - w.*v, qv)

# project window point x,y onto a sphere of radius r and center cx,cy
function sphereproject(r, cx, cy, x, y)
    qx = x-cx; qy = y-cy
    sph = r^2 - qx^2 - qy^2
    if sph < 0
        [r*qx, r*qy, 0]
    else
        [qx, qy, sqrt(sph)]
    end
end

# arcball - translate mouse motion into a rotation, as a 3x3 matrix
# x, y         - new mouse position
# lastx, lasty - old mouse position
# W, H         - window width / 2, height / 2
# ctm          - the current transform matrix (must be orthogonal)
function arcball(x, y, lastx, lasty, W, H, ctm)
    r = max(W,H)
    q0 = sphereproject(r, W, H, lastx, lasty)
    q1 = sphereproject(r, W, H, x, y)

    if q0 == q1
        return ctm
    end

    ictm = ctm'
    rx, ry, rz = ictm * cross(q0,q1)
    w, v = rotation(rx, ry, rz,
                    2acos(dot(q0,q1) / (norm(q0)*norm(q1))))

    (any(isnan,v)||isnan(w)) && return ctm

    xv = qrotate(w, v, ictm[:,1]); xv /= norm(xv)
    yv = qrotate(w, v, ictm[:,2]); yv /= norm(yv)
    zv = qrotate(w, v, ictm[:,3]); zv /= norm(zv)
    [xv[1] xv[2] xv[3]
     yv[1] yv[2] yv[3]
     zv[1] zv[2] zv[3]]
end

function canvas3d_mouseupdate(this::Canvas3D, x, y)
    this.ctm = arcball(x, y, this.lastx, this.lasty, this.GW, this.GH,
                       this.ctm)
    this.sctm = scale(this.ctm, this.scalem)
    this.lastx = x
    this.lasty = y
end

function canvas3d_button1motion(this::Canvas3D, x, y)
    canvas3d_mouseupdate(this, x, y)
    draw(getgc(this.win), this, true)
    reveal(this.win)
end

function canvas3d_button1release(this::Canvas3D, x, y)
    canvas3d_mouseupdate(this, x, y)
    draw(getgc(this.win), this, false)
    reveal(this.win)
end

# connectivity of m x n grid
function grid_polygons(m,n)
    E = Vector{Int}[]
    for k in 0:n-2, j in 0:m-2
        i = k*m+j+1
        push!(E, [i, i+1, i+m+1, i+m])  # quads
        #push!(E, [i, i+1, i+m+1])      # triangles
        #push!(E, [i, i+m+1, i+m])
    end
    E
end

# evaluate a surface over ranges of u,v parameters, giving a 3xN vertex matrix
function evalsurface(xf, yf, zf, ur, vr)
    X = Float64[ xf(u,v) for u in ur, v in vr ]
    Y = Float64[ yf(u,v) for u in ur, v in vr ]
    Z = Float64[ zf(u,v) for u in ur, v in vr ]
    N = length(ur)*length(vr)
    [reshape(X, 1, N)
     reshape(Y, 1, N)
     reshape(Z, 1, N)]
end

mutable struct Polygons3D
    V::Matrix{Float64}
    P::Vector{Vector{Int}}
    colors

    Polygons3D(V, P, colors=[ RGB(1,1,1) for i=1:length(P) ]) =
        new(V, P, colors)
    Polygons3D(V, P, coloring::Function) =
        Polygons3D(V, P,
                   [ coloring(V[1,p[1]], V[2,p[1]], V[3,p[1]]) for p in P ])
end

function draw(gc, c::Canvas3D, this::Polygons3D)
    v = project(c, this.V)
    z_ord = sortperm(this.P, by=p->v[3,p[1]])  # z sort
    set_line_width(gc, 0.5)
    for n in z_ord
        p = this.P[n]
        valid = true
        for i in p
            if isnan(v[1,i]) || isnan(v[2,i])
                valid = false; break
            end
        end
        if valid
            polygon(gc, v, p)
            set_source(gc, this.colors[n])
            fill_preserve(gc)
            set_source_rgb(gc, 0, 0, 0)
            stroke(gc)
        end
    end
end

function surf(xf::Function, yf::Function, zf::Function, ur, vr; coloring=false)
    V = evalsurface(xf, yf, zf, ur, vr)
    P = grid_polygons(length(ur), length(vr))
    if coloring === false
        Polygons3D(V, P)
    else
        Polygons3D(V, P, coloring)
    end
end

function surf(X::AbstractMatrix, Y::AbstractMatrix, Z::AbstractMatrix)
    n = length(X)
    Polygons3D([reshape(X,1,n)
                reshape(Y,1,n)
                reshape(Z,1,n)],
               grid_polygons(size(X,1),size(X,2)))
end

function plot3d(o::Polygons3D)
    w = Window("3d plot", 320, 320)
    if output_surface == :tk
        c = Canvas(w)
        pack(c, expand = true, fill = "both")
    else
        c = Canvas()
        push!(w, c)
    end

    xmin = minimum(o.V[1,:]); xmax = maximum(o.V[1,:])
    ymin = minimum(o.V[2,:]); ymax = maximum(o.V[2,:])
    zmin = minimum(o.V[3,:]); zmax = maximum(o.V[3,:])

    c3d = Canvas3D(c, xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax,
                   zmin=zmin, zmax=zmax)
    push!(c3d.models_motion, o)
    push!(c3d.models_release, o)
    c3d
end

demo_sphere() =
    plot3d(surf((u,v)->cos(v*pi)*sin(u),
                (u,v)->-cos(v*pi)*cos(u),
                (u,v)->sin(v*pi),
                0:(2pi/29):2pi, -.5:(1/17):.5,
                coloring = (x,y,z)->RGB((x-y+1)/3+.3,
                                        (z-y+1)/3+.3,
                                        z/1.5+.3)))

demo_sombrero() =
    plot3d(surf((u,v)->u,
                (u,v)->sin(hypot(u,v))/hypot(u,v),
                (u,v)->v,
                -8:.53:8, -8:.53:8))

end
