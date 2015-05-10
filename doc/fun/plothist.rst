plothist
========

.. function:: plothist(args...; kvs...)
              plothist(p::FramedPlot, args...; kvs...)
              plothist(p::FramedPlot, h::(Range{T},Array{T,1}))

   Plot a histogram of ``args``.
   ``args`` is transformed into a tuple ``(edges, counts)`` using the ``hist``
   function from ``Base``.

Example
-------

.. winston::

   x = randn(1000)
   plothist(x)
