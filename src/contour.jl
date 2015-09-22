
## Contour plot -- but this is too slow to be usable
## algorithm from MATLAB
## cf. http://www.mathworks.com/help/matlab/creating_plots/contour-plots.html
type Contourc
    contours
end

function contourc(f::Function, x, y; cs::Union{Void, Number}=nothing)

    fxy = [f(x,y) for x in x, y in y]

    ## we have edges 1,2,3,4
    ## with 1 on bottom, 2 on right, 3 top, 4 left. So
    ## exiting 1 goes to 3; 2->4, 3->1 and 4->2

    ## helper functions
    prop(c, z0, z1) = (c - z0)/(z1-z0)
    function interp_square(c, i,j)
        ## worry of i,j on boundary of 1:length(x), length(y)
        if (i < 1 || i >= length(x)) || (j < 1 || j >= length(y))
            return -1 * ones(4)
        else
            [prop(c, fxy[i,j], fxy[i+1,j]),
             prop(c, fxy[i+1,j], fxy[i+1, j+1]),
             prop(c, fxy[i,j+1], fxy[i+1, j+1]),
             prop(c, fxy[i,j], fxy[i, j+1])]
        end
    end
    insquare(x) =  any(0 .<= x .<= 1)

    function interp_point(edge, i, j, t)
        if edge == 1
            newx = x[i] + t*(x[i+1] - x[i])
            newy = y[j]
        elseif edge == 2
            newx = x[i+1]
            newy = y[j] + t*(y[j+1] - y[j])
        elseif edge == 3
            newx = x[i] + t*(x[i+1] - x[i])
            newy = y[j+1]
        else
            newx = x[i]
            newy = y[j] + t*(y[j+1] - y[j])
        end
        (newx, newy)
    end

    function which_next(edge, i, j)
        if edge == 1
            (i, j-1)
        elseif edge == 2
            (i+1, j)
        elseif edge == 3
            (i, j+1)
        else
            (i-1, j)
        end
    end



    function next_square(c, i, j, enter_edge, cx, cy, m)
##        println("Chasing $i $j")


        sq = interp_square(c, i, j)
        w = 0 .<= sq .<= 1
        ## check if 2 or more (saddle point) XXX

        ## what is next edge?
        if enter_edge == 1
            next_edge = setdiff((1:4)[w], 3)
        elseif enter_edge == 2
            next_edge = setdiff((1:4)[w], 4)
        elseif enter_edge == 3
            next_edge = setdiff((1:4)[w], 1)
        else
            next_edge = setdiff((1:4)[w], 2)
        end

        if length(next_edge) == 0
            return (cx, cy)
        end

        next_edge = next_edge[1]

        ##
        newx, newy = interp_point(next_edge, i, j, sq[next_edge])
        push!(cx, newx); push!(cy, newy)

        if m[i,j] == 1
            ## already visited
            return (cx, cy)
        end
        m[i,j] = 1
        next_square(c, which_next(next_edge, i,j)..., next_edge, cx, cy, m)
    end

    function chase_square(c, i, j, m)
##        println("chase $i $j")

        sq = interp_square(c, i, j)
        w = 0 .<= sq .<= 1

        ## chase both edges, then put together
        edges = [1:4][w]
        ## should be 2, might be more (saddle point)

        m[i,j] = 1                  # visited

        out = map(edges) do edge
            cx = Float64[]; cy = Float64[]
            t = sq[edge]
            newx, newy = interp_point(edge, i,j,t)
            push!(cx, newx); push!(cy, newy)
            next_square(c, which_next(edge, i,j)..., edge, cx, cy, m)
        end
        ## out is array of tuples
        if !isa(out[1], Void)
            ([reverse(out[1][1]), out[2][1]], [reverse(out[1][2]), out[2][2]])
        else
            nothing
        end

    end




## for each level to plot
    if isa(cs, Void)
        cs = linspace(minimum(fxy), maximum(fxy), 7+2)[2:8]
    else
        cs = [cs]
    end
    contours = Any[]

    for c in cs
        m = zeros(Int, size(fxy)...)
        c_contours = Any[]

        for i in 2:length(x)-1, j in 2:length(y)-1
            if m[i,j] == 1
                continue
            end
            sq = interp_square(c, i, j)
            if insquare(sq)
                path = chase_square(c, i,j, m)
##                println("Chased path:", path)
                if !isa(path, Void)
                    push!(c_contours, path)
                end
            else
                m[i,j] = 1              # visited
            end
        end
        push!(contours, (c, c_contours))
    end
    Contourc(contours)
end

## contour plot
function plot(f::Contourc; kwargs...)
    p = FramedPlot()
    ## out is array of tuples (c, c_countrous)
    for clevels in f.contours
        for contours in clevels[2]
            add(p, Curve(contours[1], contours[2]))
        end
    end
    for (k, v) in kwargs
        setattr(p, k, v)
    end

    p
end

