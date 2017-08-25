Curve
=====

.. function:: Curve(x::AbstractArray, y::AbstractArray, args...; kvs...)

    ``PlotComponent`` that connects data points at positions ``x`` and ``y``.
    ``args`` and ``kvs`` can be used to set additional style attributes.

Example
-------

.. winston::

    x = 0:0.05:2pi
    y = sin.(x)
    c = Curve(x, y, color="red")
    p = FramedPlot()
    add(p, c)
