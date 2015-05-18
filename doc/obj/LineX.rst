LineX
=====

.. function:: LineX(x, args...; kvs...)

    ``PlotComponent`` that draws a vertical line at position ``x``.
    ``args`` and ``kvs`` can be used to set additional style attributes.

Example
-------

.. winston::

    p = fplot(x -> 1/(2pi) * exp(-x^2/2), [-5, 5], 1000)
    l1 = LineX(-2, color="red")
    l2 = LineX(2, color="red")
    add(p, l1)
    add(p, l2)
