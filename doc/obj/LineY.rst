LineY
=====

.. function:: LineY(y, args...; kvs...)

    ``PlotComponent`` that draws a horizontal line at position ``y``.
    ``args`` and ``kvs`` can be used to set additional style attributes.

Example
-------

.. winston::

    p = fplot(atan, [-15, 15], 1000)
    l1 = LineY(pi/2, color="blue", linekind="dashed")
    l2 = LineY(-pi/2, color="blue", linekind="dashed")
    add(p, l1)
    add(p, l2)
