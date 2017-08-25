title
=====

.. function:: title(str)

   Set the title of the current plot to ``str``.

Example
-------

.. winston::

   t = 0:pi/100:8pi
   plot(t.*sin.(t), t.*cos.(t), "r;")
   title("Archimedean spiral")
