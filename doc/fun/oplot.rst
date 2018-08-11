oplot
=====

.. function:: oplot(...)

   Takes the same arguments as :func:`plot`, but overplots the current
   plot.

Example
-------

.. winston::
   :preamble: Random.seed!(802)

   randomwalk(n) = (r = randn(n); [sum(r[1:i]) for i=1:n])
   plot()
   oplot(randomwalk(300))
   oplot(randomwalk(300))
