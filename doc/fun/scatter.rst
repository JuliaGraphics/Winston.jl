scatter
=======

.. function:: scatter(x, y, s, c [,spec::AbstractString])

    Plot points at positions ``(x,y)`` with sizes ``s`` and colors ``c``.

Examples
--------

.. winston::

    n = 100
    θ = [1:n;] * 2pi/(1+φ)
    r = sqrt(1:n)
    scatter(r.*cos(θ), r.*sin(θ), 2, r, "*")

