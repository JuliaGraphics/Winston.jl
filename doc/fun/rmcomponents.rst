rmcomponents
===

.. function:: rmcomponents(p::FramedPlot, i::Integer) -> Array{PlotComponents,1}
              rmcomponents(p::FramedPlot, i::Type)
              rmcomponents(p::FramedPlot, v::AbstractVector)
   
   Remove the components contained in the plot ``p'' as identified by their
   position or their type (e.g. ``Curve``, ``Points``, ``Legend``, etc.)

