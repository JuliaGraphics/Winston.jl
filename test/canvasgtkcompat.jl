# minimalistic compatibility definitions
const Toplevel = Gtk4.GtkWindowLeaf
pack(x...;y...) = nothing
function Canvas(w, x, y)
  c = Gtk4.GtkCanvas()
  Gtk4.G_.set_size_request(c, x, y) 
  #w |> c
  w[] = c
  show(c)
  return c
end
