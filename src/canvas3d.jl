using Tk
using Cairo

type Canvas3D
    win::Canvas
    ctm::Matrix{Float64}
    sctm::Matrix{Float64}
    lastx::Int
    lasty::Int
    r::Float64
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
    
    function Canvas3D(win; xmin=0, xmax=Tk.width(win)-1, ymin=0, ymax=Tk.height(win)-1,
                      zmin=-10, zmax=10)
        this = new(win)
        this.xmin = xmin; this.xmax = xmax
        this.ymin = ymin; this.ymax = ymax
        this.zmin = zmin; this.zmax = zmax
        this.ctm = eye(3)

        configure(this)
        win.mouse.button1press = (c,x,y)->canvas3d_mousedown(this,x,y)
        win.mouse.button1motion = (c,x,y)->canvas3d_button1motion(this,x,y)
        win.redraw = function (c)
            configure(this)
            draw(cairo_context(this.win), this)
        end
        this
    end
end

cube_verts(x0, x1, y0, y1, z0, z1) =
    [x0 x1 x1 x0 x0 x1 x1 x0;
     y0 y0 y1 y1 y0 y0 y1 y1;
     z0 z0 z0 z0 z1 z1 z1 z1]

function configure(this::Canvas3D)
    scalem = [0.577 * (Tk.width(this.win)-1)/(this.xmax - this.xmin),
              0.577 * (Tk.height(this.win)-1)/(this.ymax - this.ymin),
              0]
    scalem[3] = 0.5(scalem[1]+scalem[2])
    this.scalem = scalem
    this.sctm = diagmm(this.ctm, scalem)

    this.center = [(this.xmax+this.xmin)/2,
                   (this.ymax+this.ymin)/2,
                   (this.zmax+this.zmin)/2]
    this.boxv = cube_verts(this.xmin, this.xmax, this.ymin, this.ymax,
                           this.zmin, this.zmax)
    this.GW = Tk.width(this.win)/2
    this.GH = Tk.height(this.win)/2
    this.r = min(this.GW,this.GH)
    this.wincenter = [this.GW, this.GH, 0]
    this
end

function project(this::Canvas3D, v)
    this.sctm * (v-this.center) + this.wincenter
end

function polygon(gc, verts::Matrix, idx::Vector)
    move_to(gc, verts[1,idx[1]], verts[2,idx[1]])
    for i=2:length(idx)
        n = idx[i]
        line_to(gc, verts[1,n], verts[2,n])
    end
    close_path(gc)
end

const cube4sides = {[1,5,6,2], [2,6,7,3], [3,7,8,4], [4,8,5,1]}

function draw(gc, this::Canvas3D)
    bv = similar(this.boxv)
    for i=1:size(bv,2)
        bv[:,i] = project(this, this.boxv[:,i])
    end

    edges = sortby(cube4sides, p->mean(bv[3,:][p]))

    set_source_rgb(gc, 1, 1, 1)
    paint(gc)

    set_source_rgb(gc, 0, 0, 0)
    set_line_width(gc, 0.6)

    polygon(gc, bv, edges[1])
    polygon(gc, bv, edges[2])
    stroke(gc)

    # draw contents here

    polygon(gc, bv, edges[3])
    polygon(gc, bv, edges[4])
    stroke(gc)

    reveal(this.win)
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
    q = [cx-x, cy-y, 0]
    sph = r^2 - q[1]^2 - q[2]^2
    if sph < 0
        q *= r
    else
        q[3] = sqrt(sph)
    end
    q
end

function canvas3d_button1motion(this::Canvas3D, x, y)
    r = this.r
    GW = this.GW
    GH = this.GH
    q0 = sphereproject(r, GW, GH, this.lastx, this.lasty)
    q1 = sphereproject(r, GW, GH, x, y)

    this.lastx = x
    this.lasty = y
    
    ictm = this.ctm'
    xx, yy, zz = ictm * cross(q0,q1)
    w, r = rotation(xx, yy, zz,
                    2acos(dot(q0,q1) / (norm(q0)*norm(q1))))

    (any(isnan,r)||isnan(w)) && return

    xv = qrotate(w, r, ictm[:,1]); xv /= norm(xv)
    yv = qrotate(w, r, ictm[:,2]); yv /= norm(yv)
    zv = qrotate(w, r, ictm[:,3]); zv /= norm(zv)
    this.ctm = [xv yv zv]'
    this.sctm = diagmm(this.ctm, this.scalem)

    draw(cairo_context(this.win), this)
end

function demo()
    w = Window("3d", 320, 300)
    c = Canvas(w)
    pack(c, {:expand => true, :fill => "both"})
    c3d = Canvas3D(c, zmin=0, zmax=300)
    c.redraw(c)
    c3d
end
