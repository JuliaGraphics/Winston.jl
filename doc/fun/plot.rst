plot
====

.. function:: plot(y [,spec])
              plot(x, y [,spec])
              plot(x, y [,spec], x2, y2 [,spec], ...)

   Plot ``y`` vs ``x``, with optional :ref:`style format <ref-style-format>`
   ``spec``. If ``x`` is missing, ``1:length(y)`` is used instead.

Example
--------

.. winston::

    x = 0:0.1:10
    y = sin.(x)
    y2 = sin.(2sin.(2sin.(x)))
    plot(x, y, "g^", x, y2, "b-o")

.. _ref-style-format:

Style format
------------

========= ========================
Character Meaning
========= ========================
``-``     solid line
``:``     dotted line
``;``     dot-dashed line
``-.``    dot-dashed line
``--``    dashed line
``+``     plus symbol
``o``     circle symbol
``*``     asterisk symbol
``.``     dot symbol
``x``     cross symbol
``s``     square symbol
``d``     diamond symbol
``^``     triangle symbol
``v``     inverted triangle
``>``     right-pointing triangle
``<``     left-pointing triangle
``y``     yellow
``m``     magenta
``c``     cyan
``r``     red
``g``     green
``b``     blue
``w``     white
``k``     black
========= ========================

