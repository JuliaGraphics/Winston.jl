Histogram
=========

.. function:: Histogram(edges, counts, args...; kvs...)

    ``PlotComponent`` to draw a histogram. If ``edges`` is of length N,
    ``counts`` must be of length N - 1, because ``counts`` specifies the
    height of the plot in the interval ``(edges[i], edges[i+1])``.

    It might be more convenient to use the ``plohist`` function instead.

Attributes
----------

+----------------+----------+----+
| drop_to_zero   | Bool     |    |
+----------------+----------+----+

Example
-------

.. winston::

    edges = -10:11
    counts = abs.(-10:10)
    h = Histogram(edges, counts)
    p = FramedPlot()
    add(p, h)
