colormap
========

.. function:: colormap(name::String [, n=256])

    Set the current colormap to ``name``, with ``n`` colors.

.. function:: colormap(array::Vector{ColorValue})

    Set the current colormap to ``array``.

.. function:: colormap()

    Return the current colormap.

Example
-------

.. winston::

   colormap("jet", 10)
   imagesc(reshape(1:10000,100,100))

