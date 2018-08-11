PlotLabel
=========

.. function:: PlotLabel(x, y, str, args...; kvs...)

    ``PlotComponent`` to add a label with text given by ``str`` at position
    ``(x, y)``. The coordinates ``x`` and ``y`` are normalized to range
    between 0 and 1.
    ``args`` and ``kvs`` can be used to set additional style attributes.

Example
-------

.. winston::

    x = range(0, stop=10, length=100)
    p = plot(x, sin.(x))
    l = PlotLabel(0.5, 0.8, "Hello World!")
    add(p, l)
