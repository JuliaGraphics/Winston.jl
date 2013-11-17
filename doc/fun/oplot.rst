oplot
=====

.. function:: oplot(...)

   Takes the same arguments as :func:`plot`, but overplots the current
   plot.

Example
-------

.. winston::

   walk(n) = (r = randn(n); [sum(r[1:i]) for i=1:n])
   plot()
   oplot(walk(100))
   oplot(walk(100))

