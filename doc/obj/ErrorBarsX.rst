ErrorBarsX
==========

.. function:: ErrorBarsX(y, lo, hi, args...; kvs...)

    ``PlotComponent`` to draw horizontal errorbars at vertical positions ``y``.
    ``lo`` specifies the lower, ``hi`` the upper end of the error bar. Both
    must have the same length as ``y``.
    ``args`` and ``kvs`` can be used to set additional style attributes.

.. function:: SymmetricErrorBarsX(x, y, err, args...)

    ``PlotComponent`` to draw symmetric horizontal errorbars with length
    ``2 * err`` at positions ``(x, y)``.
    ``err`` can either be a scalar, which gives each errorbar the same length,
    or an Array with the same length as ``x`` and ``y``, which allows to assign
    a different error to each data point.
    ``args`` can be used to set additional style attributes.

Attributes
----------

+---------------+--------+----+
| barsize       | Real   |    |
+---------------+--------+----+

Example
-------

.. winston::

    x = 1:10
    err = (1:10) ./ 10
    errbars = SymmetricErrorBarsX(x, x, err)
    p = scatter(x, x)
    add(p, errbars)
