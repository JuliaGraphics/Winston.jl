quartileboxes
=======

.. function:: quartileboxes(x [;notch=false])

    Visualize the distribution ``x``. If ``x`` is a matrix, visualize each column. The median of ``x`` is represented by a horizontal line inside a box extending from the 25th to the 75th percentile of ``x``. Vertical lines, called whiskers, span 1.5 times the inter-quartile range. Data outside of this range are represented as dots. If the keyword argument ``notch`` is set to ``true``, a notch is drawn around around the median to indicate the confidence of the median.

Examples
=======

.. winston::

    X = rand((200,10))
    quartileboxes(X ;notch=true)
