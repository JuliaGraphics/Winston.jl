colormap
========

.. function:: colormap(name::AbstractString [, n=256])

    Set the current colormap to ``name``, with ``n`` colors.
    ``name`` may be one of the supported colormap names in ``Color.colormap``
    (see https://github.com/JuliaLang/Color.jl#colormaps) or ``jet``.

.. function:: colormap(array::Vector{ColorValue})

    Set the current colormap to ``array``.

.. function:: colormap()

    Return the current colormap.

Example
-------

.. winston::

   colormap("jet", 10)
   imagesc(reshape(1:10000,100,100))

