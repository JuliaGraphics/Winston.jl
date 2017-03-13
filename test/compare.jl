import Cairo
using Colors
using Base.Test
using Winston
using Compat; import Compat.String

module ImageComparisons
    using Winston, Colors
    include("examples.jl")
    include("issues.jl")
    include("plot.jl")
end

function read_png_data(fn::String)
    surface = Cairo.read_from_png(fn)
    w = Cairo.width(surface)
    h = Cairo.height(surface)
    p = ccall((:cairo_image_surface_get_data,Cairo._jl_libcairo),
              Ptr{UInt8}, (Ptr{Void},), surface.ptr)
    a = pointer_to_array(convert(Ptr{UInt32},p), (convert(Int,w),convert(Int,h)))
    copy(a)
end

function img_dist{T<:Array{UInt32,2}}(img1::T, img2::T)
    @assert size(img1) == size(img2)
    s = 0.
    for i = 1:length(img1)
        a = convert(RGB, reinterpret(RGB24, img1[i]))
        b = convert(RGB, reinterpret(RGB24, img2[i]))
        s += colordiff(a, b)
    end
    s
end

function main()
    root = dirname(task_local_storage()[:SOURCE_PATH])
    dir1,dir2 = "$root/_baseline","$root/_current"
    isdir(dir1) || mkdir(dir1)
    isdir(dir2) || mkdir(dir2)

    for name in sort(names(ImageComparisons))

        name == :ImageComparisons && continue
        p = eval(:((ImageComparisons.$name)()))

        fn1 = "$dir1/$name.png"
        fn2 = "$dir2/$name.png"
        isfile(fn1) || savefig(p, fn1)
        savefig(p, fn2)

        img1 = read_png_data(fn1)
        img2 = read_png_data(fn2)

        d = img_dist(img1, img2)
        println("$name $d")
        d < 0.1 || error("$name failed")
    end
end

main()
