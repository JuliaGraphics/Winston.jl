FillBetween
===========

.. function:: FillBetween(x1, y1, x2, y2, arg...; kvs...)

    ``PlotComponent`` that fills the area between the lines connecting the data
    points in ``x1``, ``y1`` and ``x2``, ``y2`` respectively.
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

    x1 = 0:0.05:2pi
    x2 = x1
    y1 = 0.5 * sin.(x1)
    y2 = 1.0 * sin.(x2)
    f = FillBetween(x1, y1, x2, y2, fillcolor="magenta")
    p = FramedPlot()
    add(p, f)
