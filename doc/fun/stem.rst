stem
====

.. function:: stem(y [,spec::ASCIIString])
              stem(x, y [,spec::ASCIIString])

    Stem plots.

Example
-------

.. winston::

    x = range(0, stop=5pi, length=40)
    stem(x, sin.(x), "r")
