fplot
=====

.. function:: fplot(f::Function, limits [,spec])

   Plot the function ``f`` between the specified ``limits``.

Example
-------

.. winston::

   fplot(x->sin(x^2), [0,8], "b")

