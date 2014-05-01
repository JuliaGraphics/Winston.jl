stem
====

.. function:: stem(y [,spec::ASCIIString])
              stem(x, y [,spec::ASCIIString])

    Stem plots.

Example
-------

.. winston::

    x = linspace(0, 5pi, 40)
    stem(x, sin(x), "r")

