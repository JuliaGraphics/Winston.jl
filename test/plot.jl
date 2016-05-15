
const r = -3:6
const v = collect(r)
const v2 = 1.:10.
const m = reshape(1:100, 10, 10)
const m2 = reshape(1:35, 5, 7)

const args = [
    :(),                                # nil
    :(r,),                              # vec (range)
    :(v,),                              # vec (array)
    :(v',),                             # vec (transposed array)
    :(m,),                              # mat
    :(complex(v,v),),                   # complex vec
    :(complex(m,m),),                   # complex mat
    :(v,v2),                            # vec/vec
    :(m,m),                             # mat/mat (square)
    :(m2,m2),                           # mat/mat (non-square)
    :(v,m),                             # vec/mat
    :(2:6,m2),                          # vec/mat (cols)
    :(2:8,m2),                          # vec/mat (rows)
    :(m2,2:6),                          # mat/vec (cols)
    :(m2,2:8),                          # mat/vec (rows)
]

for i = 1:length(args)
    f = Symbol(@sprintf("plot%03d",i))
    body = copy(args[i])
    body.head = :call
    unshift!(body.args, :plot)
    push!(body.args, Expr(:kw, :title, string(body)))
    eval(Expr(:toplevel, Expr(:export, f), :(($f)() = $body)))
end

