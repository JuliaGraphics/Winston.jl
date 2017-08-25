Image
=====

.. function:: Image(xrange, yrange, img, arg...; kvs...)

    ``PlotComponent`` to draw RGB data in ``img``. ``img`` must be of type
    ``Array{UInt32,2}``. ``xrange`` and ``yrange`` are used to set the range
    of the corresponding axis.

Example
-------

.. winston::

    N = 32
    imgdata = reshape([ 0x00ffffff / (N^2-1) * i for i in 0:(N^2-1) ], (N, N))
    img = Image((1, N), (1, N), convert(Array{UInt32,2}, imgdata))
    p = FramedPlot()
    add(p, img)
