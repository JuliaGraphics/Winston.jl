Frequently Asked Questions
==========================

Why is nothing displayed when I call ``plot`` in a script?
----------------------------------------------------------

In the REPL, if you type::

    julia> s = "a string"

it prints::

    julia> s = "a string"
    "a string"

In a script, the line::

    s = "a string"

prints nothing. You have to ask for it to be printed::

    s = "a string"
    println(s)

Likewise for ``plot``, if you want it to be displayed, you have to request it::

    p = plot(...)
    display(p)


What kind of typesetting can I use in plot annotations?
----------------------------------------------------------
Currently there is a only limited support for TeX-like formulae typesetting.

There are two ways of putting the greek symbols in the plot annotations.

You can use unicode symbols directly in the annotation string::

    plot(...,xlabel="ξ",ylabel="ϕ(ξ)")

or you can use the TeX-like syntax::

    plot(...,xlabel="\\xi",ylabel="\\phi(\\xi)")

(note the escaped ``\\``).

Limited typesetting is available in a form of superscript (``^``) and subscript (``_``).  It is also possible to group the symbols with ``{`` and ``}`` just as in TeX::

    plot(...,xlabel="\\xi^2",ylabel="\\phi_{\\xi\\xi}(\\xi)")

For the full list of supported symbols you can browse `constants.jl <https://github.com/JuliaLang/Cairo.jl/blob/master/src/constants.jl>`_.  Because text is rendered with the Pango library you can also use all the `markup <https://developer.gnome.org/pango/stable/PangoMarkupFormat.html>`_ available for Pango.  In particular, you can produce bold, italic or monospace text via::

    "<b>text<\b>"
    "<i>text<\i>"
    "<tt>text<\tt>"
