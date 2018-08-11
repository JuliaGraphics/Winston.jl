imagesc
=======

.. function:: imagesc(::Matrix)

    Plot an image.

Examples
--------

.. winston::

    n = 300
    x = range(10., stop=-10., length=n)
    t = range(-1., stop=1., length=n)
    z = (3. .+ 4*cosh.(2x' .- 8t) .+ cosh.(4x' .- 64t)) ./
        (3*cosh.(x' .- 28t) .+ cosh.(3x' .- 36t)) .^ 2

    imagesc(z, (minimum(z),0.6maximum(z)))
