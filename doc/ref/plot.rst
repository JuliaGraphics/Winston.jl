.. _ref-plot:

******
 plot
******

.. function:: plot(y [,spec])
              plot(x, y [,spec])
              plot(x, y, [spec,] x2, y2, [spec,] ...)

Examples
--------

.. winston::

    x = 0:0.1:10
    y = sin(x)
    y2 = cos(x)
    plot(x, y, "g^", x, y2, "b-o")

