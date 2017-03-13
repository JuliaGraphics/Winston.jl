text
====

.. function:: text(x::Real, y::Real, s::AbstractString; kvs...)

   Add the text in ``s`` to the current plot at coordinates ``x`` and ``y``.

Example
-------

.. winston::

   fplot(x -> x^2, [-4, 4])
   text(-2, 10, "Hello World!")

