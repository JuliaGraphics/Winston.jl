# minimalistic compatibility definitions
const Toplevel = Gtk.WindowLeaf
pack(x...;y...) = nothing
Canvas(w, x, y) = ((w |> (c=show(Gtk.@Canvas(x,y)))); c)
