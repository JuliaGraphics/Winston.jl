module ImageComparisons
    using Winston, Compat, Colors
    using Printf, Random
    include("examples.jl")
    include("issues.jl")
    include("plot.jl")
end

function read_png_data(fn::String)
    surface = Cairo.read_from_png(fn)
    w = Cairo.width(surface)
    h = Cairo.height(surface)
    a = Array{UInt32}(undef, convert(Int, w), convert(Int, h))
        
    p = ccall((:cairo_image_surface_get_data,Cairo._jl_libcairo),
              Ptr{UInt32}, (Ptr{Cvoid},), surface.ptr)

    for i = 1:length(a)
        a[i] = unsafe_load(p, i)
    end
    return a
end

function img_dist(img1::Matrix{UInt32}, img2::Matrix{UInt32})
    @assert size(img1) == size(img2)
    s = 0.
    for i = 1:length(img1)
        a = convert(RGB, reinterpret(RGB24, img1[i]))
        b = convert(RGB, reinterpret(RGB24, img2[i]))
        s += colordiff(a, b)
    end
    s
end

@testset "Image comparison" begin
    root = dirname(task_local_storage()[:SOURCE_PATH])
    dir1, dir2 = joinpath(root, "_baseline"), joinpath(root, "_current")
    isdir(dir1) || mkdir(dir1)
    isdir(dir2) || mkdir(dir2)

    for name in sort!(names(ImageComparisons))
        name == :ImageComparisons && continue

        @testset "$name" begin
            println("Testing $name")
            figure()
            func = eval(:(ImageComparisons.$name))
            global p = func()

            fn1 = joinpath(dir1, "$name.png")
            fn2 = joinpath(dir2, "$name.png")
            isfile(fn1) || savefig(p, fn1)

            savefig(p, fn2)

            img1 = read_png_data(fn1)
            img2 = read_png_data(fn2)
            @test size(img1) == size(img2)

            @test img_dist(img1, img2) < 0.1
        end
    end
end
