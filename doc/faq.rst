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

Likewise for ``plot``, if you want it to be displayed, you have to request it:

    p = plot(...)
    display(p)

