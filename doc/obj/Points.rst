Points
======

.. function:: Points(x::Real, y::Real, args...; kvs...)

    ``PlotComponent`` to plot points at positions given by ``x`` and ``y``.
    ``args`` and ``kvs`` can be used to set additional style attributes.

Example
-------

.. winston::

    x = 0:0.1:2pi
    y1 = sin.(x) + randn(length(x)) / 10
    y2 = x + randn(length(x)) / 10

    p1 = Points(x, y1, color="red", symbolkind="plus")
    p2 = Points(x, y2, color="blue", symbolkind="diamond")

    p = FramedPlot()
    add(p, p1)
    add(p, p2)
