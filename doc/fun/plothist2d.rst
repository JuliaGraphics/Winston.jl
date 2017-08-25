plothist2d
==========

.. function:: plothist2d(args...; kvs...)
              plothist2d(p::FramedPlot, args...; kvs...)
              plothist2d(p::FramedPlot, h::(Union{Array{T,1},Range{T}},Union{Array{T,1},Range{T}},Array{Int64,2}))

   Plot a 2D histogram of ``args``.
   ``args`` is transformed into a tuple ``(edges1, edges2, counts)`` using the
   ``hist2d`` function from ``Base``.

Example
-------

.. winston::

   x = exp.(-randn(1000) / 2)
   y = randn(1000)
   nbins = 50

   plothist2d([x y], nbins)

