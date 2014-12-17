
Table
=====

.. function:: Table(nrows, ncols)

   Arrange other containers in a grid.

To add a container to a specific cell, use::

    t = Table(nrows, ncols)
    t[i,j] = container

where ``t`` is the ``Table`` object, ``i`` is the row number, and ``j`` is
the column number.

Attributes
----------

+---------------+--------+----+
| cellpadding   | Real   |    |
+---------------+--------+----+
| cellspacing   | Real   |    |
+---------------+--------+----+

