Stems
=====

.. function:: Stems(x, y, args...; kvs...)

    ``PlotComponent`` to draw stems at vertical positions ``x`` with height
    ``y``.
    ``args`` and ``kvs`` can be used to set additional style attributes.

Example
-------

.. winston::

    x = range(-5, stop=5, length=50)
    y = 1 / sqrt(2pi) * exp.(-x.^2 / 2)

    s = Stems(x, y, color="blue")
    p = FramedPlot()
    add(p, s)
