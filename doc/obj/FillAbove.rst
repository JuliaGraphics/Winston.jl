FillAbove
=========

.. function:: FillAbove(x, y, args...; kvs...)

    ``PlotComponent`` that fills the area above the line connecting the data
    points in ``x`` and ``y``.
    ``args`` and ``kvs`` can be used to set additional style attributes.

Attributes
----------

+-------------+----------+----+
| fillcolor   | Integer  |    |
+-------------+----------+----+
| fillkind    | Integer  |    |
+-------------+----------+----+

Example
-------

.. winston::

    x = 0:100
    f = FillAbove(x, x.^2, fillcolor="cyan")
    p = FramedPlot()
    add(p, f)
