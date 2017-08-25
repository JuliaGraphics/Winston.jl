hold
====

.. function:: hold(::Bool)
              hold()

    Sets whether the current plot is cleared before a new plot is drawn.
    ``hold()`` toggles the current setting.

Example
-------

.. winston::

   x = 0:0.1:2pi
   plot(x, sin.(x), "r")
   hold(true)
   fplot(cos, [0,2pi], "g")

