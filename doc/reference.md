
Winston Reference Guide
=======================

Overview
--------

Winston provides a set of objects for constructing 2d vector
plots.

Winston objects fall into two categories: containers and components.
Containers are things like plots and tables, and can be turned into
graphical output. Components can't be visualized on their own, but only
when added to containers. Containers can contain other containers.

<table>
<tr>
<td> Containers </td>
<td> Components </td>
<td></td>
</tr>
<tr>
<td valign="top">
<pre>
FramedArray       
FramedPlot
Plot
Table
</pre>
</td>
<td valign="top">
<pre>
Circle(s)
Curve
DataBox
DataInset
DataLabel/Label
DataLine/Line
Ellipse(s)
ErrorBarsX
ErrorBarsY
FillAbove
FillBelow
FillBetween
</pre>
</td>
<td valign="top">
<pre>
Legend
LineX
LineY
PlotBox
PlotInset/Inset
PlotLabel
PlotLine
Point(s)
Slope
SymmetricErrorBarsX
SymmetricErrorBarsY
</pre>
</td>
</tr>
</table>


TeX emulation
-------------

Winston includes a simple TeX emulator which recognizes subscripts,
superscripts, and many of the math symbol definitions from Appendix F
of _The TeXbook_. All text strings passed to Winston are
interpreted as TeX.

PlotContainer
-------------

### Methods ###

#### `file( container, filename, options... )`

Save container to a file. Valid filename extensions are
`"eps"`, `"png"`, and `"svg"`.

#### `getattr( container, key [, notfound] )`

Returns the value of the attribute named `key` if found, otherwise `notfound`.

#### `setattr( container, key, val )`

Sets the attribute named `key` to `val`.

#### `x11( container )`

Plot the container in an X window.

### Attributes ###

The following attributes are common to all containers.

<table>

<tr><td> aspect_ratio </td><td> Nothing | Real </td>
<td>
    Force the aspect ratio (height divided by width) to be a particular value.
    If `Nothing` the container fills the available space.
</td>
</tr>

<tr><td> page_margin </td><td> Real </td>
<td>
    Extra padding applied when rendering the head container
    (ie, the container from which show(), write(), etc was called).
</td>
</tr>

<tr><td> title </td><td> Nothing | String </td>
<td>
    Draw a plot-centered supertitle.
</td>
</tr>

<tr><td> title_offset </td><td> Real </td>
<td>
    The distance between the title and the container's contents.
</td>
</tr>

<tr><td> title_style </td><td> Style </td>
<td>
</td>
</tr>

</table>


FramedPlot() <: PlotContainer
-----------------------------

This object represents a framed plot, where the axes surround
the plotting region, instead of intersecting it.
You build a plot by adding components:
```
p = FramedPlot()
add( p, component... )
```
Components are rendered in the order they're added.

### Basic Attributes 

<table>

<tr><td> xlabel </td><td> String </td>
<td> The x-axis label (bottom of the frame).</td>
</tr>

<tr><td> xlog </td><td> Bool </td>
<td>If true use log scaling, otherwise linear.</td>
</tr>

<tr><td> xrange </td><td> (Nohing | Real, Nothing | Real) </td>
<td>
    The x-axis left and right limits, respectively.
    Limits set to `nothing` are chosen automatically.
</td>
</tr>

<tr><td> ylabel </td><td> String </td>
<td> The y-axis label (left of the frame).</td>
</tr>

<tr><td> ylog </td><td> Bool </td>
<td>If true use log scaling, otherwise linear.</td>
</tr>

<tr><td> yrange </td><td> (Nothing | Real, Nothing | Real) </td>
<td>
    The y-axis left and right limits, respectively.
    Limits set to `nothing` are chosen automatically.
</td>
<td></td>
</tr>

</table>

These should be sufficient for casual use, but often you'll want greater
control over the frame.

### Axis Attributes

Each side of the frame is an independent axis object:
`p.x1` (bottom), `p.y1` (left), `p.x2` (top), and `p.y2` (right).
The axis attributes below apply to each of these objects. So for example,
to label the right side of the frame, you would say:
```
setattr( p.y2, "label", "something" )
```
The label, log, and range attributes are the same as the ones above.
For instance, when you set `p.xlog` you're actually setting
`p.x1.log`.

<table>

</tr><tr><td>  draw_axis </td><td> Bool </td>
<td>
    If false the spine, ticks, and subticks are not drawn;
    otherwise it has no effect.
</td>
</tr>

</tr><tr><td> draw_grid </td><td> Bool </td>
<td>
    Grid lines are parallel to and coincident with the ticks.
</td>
</tr>

</tr><tr><td> draw_nothing </td><td> Bool </td>
<td>
    If true nothing is drawn; otherwise it has no effect.
</td>
</tr>

</tr><tr><td> draw_spine </td><td> Bool </td>
<td>
    The spine is the line perpendicular to the ticks.
</td>
</tr>

</tr><tr><td> draw_subticks </td><td> Nothing | Bool
<td>
    If set to `nothing` subticks will
    be drawn only if ticks are drawn.
</td>
</tr>

</tr><tr><td> draw_ticks </td><td> Bool </td>
<td></td></tr>

</tr><tr><td> draw_ticklabels </td><td> Bool </td>
<td></td></tr>

</tr><tr><td> grid_style </td><td> Style </td>
<td></td></tr>

</tr><tr><td> label </td><td> String </td>
<td></td></tr>

</tr><tr><td> label_offset </td><td> Real </td>
<td></td></tr>

</tr><tr><td> label_style </td><td> Style </td>
<td></td></tr>

</tr><tr><td> log </td><td> Bool </td>
<td></td></tr>

</tr><tr><td> range </td><td> (Nothing | Real, Nothing | Real)</td>
<td>
    Left and right limits, respectively.
    Limits set to `nothing` are chosen automatically.
</td>
</tr>

</tr><tr><td> spine_style </td><td> Style </td>
<td></td></tr>

</tr><tr><td> subticks </td><td> Nothing | Integer | Real[]
<td>
    Similar to `ticks\*`, except when set to an integer
    it sets the number of subticks drawn between ticks, not the total number of
    subticks.
</td>
</tr>

</tr><tr><td> subticks_size </td><td> Real
<td></td></tr>

</tr><tr><td> subticks_style </td><td> Style
<td></td></tr>

</tr><tr><td> ticks </td><td> Nothing | Integer | Real[] </td>
<td>
    If set to `nothing` ticks will be automagically generated.
    If set to an integer _n_, _n_ equally spaced ticks will be drawn.
    You can provide your own values by setting `ticks` to a sequence.
</td>
</tr>

</tr><tr><td> ticks_size </td><td> Real </td>
<td></td></tr>

</tr><tr><td> ticks_style </td><td> Style </td>
<td></td></tr>

</tr><tr><td> tickdir </td><td> +1 | -1 </td>
<td>
    This controls the direction the ticks and subticks are drawn in.
    If +1 they point toward the ticklabels and if -1 they
    point away from the ticklabels.
</td>
</tr>

</tr><tr><td> ticklabels </td><td> Nothing | String[]
<td>
    Ticklabels are the labels marking the values of the ticks.
    You can provide your own labels by setting `ticklabels` to a list
    of strings.
</td>
</tr>

</tr><tr><td> ticklabels_dir </td><td> +1 | -1 </td>
<td></td></tr>

</tr><tr><td> ticklabels_offset </td><td> Real </td>
<td></td></tr>

</tr><tr><td> ticklabels_style </td><td> Style </td>
<td></td></tr>

</table>

So let's say you wanted to color all the ticks red.
You could write:
``` julia
# XXX:doesn't work yet
p.x1.ticks_style["color"] = "red"
p.x2.ticks_style["color"] = "red"
p.y1.ticks_style["color"] = "red"
p.y2.ticks_style["color"] = "red"
```
but it's tedious, and hazardous for your hands.
`FramedPlot` provides a mechanism for manipulating
groups of axes, through the use of the following pseudo-attributes:
```
frame          ==>     .x1, .x2, .y1, .y2
frame1         ==>     .x1, .y1
frame2         ==>     .x2, .y2
x              ==>     .x1, .x2
y              ==>     .y1, .y2
```
which lets you write
``` julia
# XXX:doesn't work yet
p.frame.ticks_style["color"] = "red"
```
instead.

FramedArray( nrows, ncols ) <: PlotContainer
--------------------------------------------

Use this container if you want to plot an array of similar plots.
To add a component to a specific cell, use
``` julia
add( a[i,j], component... )
```
where `a` is a `FramedArray` object,
`i` is the row number, and `j` is the column number.
You can also add a component to all the cells at once using:
``` julia
add( a, component... )
```

### Attributes: (in addition to the basic `FramedPlot` ones) ###

<table>

<tr><td> cellspacing </td><td> Real </td>
<td></td></tr>

<tr><td> uniform_limits </td><td> Bool </td>
<td>
    If set to 1 every cell will have the same limits.
    Otherwise they are only forced to be the same across
    rows and down columns.
</td>
</tr>

</table>

Plot() <: PlotContainer
-----------------------

`Plot` behaves the same as `FramedPlot`, except no axes,
axis labels, or titles are drawn.

### Attributes

(same as `FramedPlot`, minus the title/label options)

Table( nrows, ncols ) <: PlotContainer
--------------------------------------

This container allows you to arrange other containers in a grid.
To add a container to a specific cell, use
```
t = Table(nrows, ncols)
t[i,j] = container
```
where `t` is the `Table` object,
`i` is the row number, and `j` is the column number.

### Attributes ###

<table>
<tr><td> cellpadding </td><td> Real </td>
<td></td></tr>
<tr><td> cellspacing </td><td> Real </td>
<td></td></tr>
</table>


Components
----------

Components named `Data*` take data coordinates,
while `Plot*` objects take plot coordinates,
where the lower-left corner of the plot is at `(0,0)`
and the upper-right corner is at `(1,1)`.

#### Circle( x, y, r ) <br> Circles( x, y, r )

Draw circles centered at `(x,y)` with radius `r`.

#### Curve( x, y )

Draw lines connecting `(x[i],y[i])` to `(x[i+1],y[i+1])`.

#### Ellipse( x, y, rx, ry, angle ) <br> Ellipses( x, y, rx, ry, angle )

Draw ellipses centered at `(x,y)`,
with x-radius `rx`, y-radius `ry`,
and rotated counterclockwise by `angle`.

#### ErrorBarsX( y, xerr_lo, xerr_hi ) <br> ErrorBarsY( x, yerr_lo, yerr_hi )

Draw [XY] error bars.
Specifically, the bars extend from
`(xerr_lo[i],y[i])` to `(xerr_hi[i],y[i])`
for `ErrorBarsX`, and
`(x[i],yerr_lo[i])` to `(x[i],yerr_hi[i])`
for `ErrorBarsY`.

#### FillAbove( x, y ) <br> FillBelow( x, y )

`FillAbove/Below` fills the region bounded below/above, respectively,
by the curve `{x,y}`.

#### FillBetween( xA, yA, xB, yB )

Fill the region bounded by the curves `{xA,yA}` and `{xB,yB}`.

#### LineX( x ) <br> LineY( y )

Draw a line of constant [xy].

#### Point( x, y ) <br> Points( x, y )

Draw symbols at the set of points `(x,y)`.

#### Slope( slope, p )

Draw the line `y = p[2] + slope*(x - p[1])`.

#### SymmetricErrorBarsX( x, y, err ) <br> SymmetricErrorBarsY( x, y, err )

Draw error bars extending from
`(x[i]-err[i],y[i])` to `(x[i]+err[i],y[i])`
for `SymmetricErrorBarsX`, and
`(x[i],y[i]-err[i])` to `(x[i],y[i]+err[i])`
for `SymmetricErrorBarsY`.

#### DataBox( p, q ) _[aka Box]_ <br> PlotBox( p, q )

Draws the rectangle defined by points `p` and `q`.

#### DataInset( p, q, container ) <br> PlotInset( p, q, container ) _[aka Inset]_

Draws `container` in the rectangle defined by
points `p` and `q`.

#### DataLabel( x, y, "label" ) _[aka Label]_ <br> PlotLabel( x, y, "label" )

Write the text `string` at the point `(x,y)`.
Alignment is governed by `halign` and `valign`.

#### DataLine( p, q ) _[aka Line]_ <br> PlotLine( p, q )

Draws a line connecting points `p` and `q`.

#### Legend( x, y, components )

TBD. See example 2.


Style 
-----

The style properties of components (e.g., color) are controlled 
through a common set of keyword options passed during object creation.
For example,
```
c = Curve( x, y, "color", "red" )
```
Keywords which are not relevant (for instance, setting `fontface` for a `Line` object)
are ignored. After creation, style keywords can be set using the
`style` member function:
```
style( c, "linekind", "dotted" )
```

<table>
<tr><td> color <br> fillcolor <br> linecolor </td><td> Integer | String </td>
<td>
Set line or fill color (`color` sets both).
A six digit hexadecimal integer, `0xRRGGBB`, is interpreted as an RGB triple.
Strings specify color names (eg "red", "lightgrey").
A list of acceptable names can be found in `rgb.txt` (usually found in `/usr/lib/X11/`)
and `colors.txt` (usually found in `/usr/share/libplot/`).
</td></tr>

<tr><td> linekind </td><td> String
</td><td>
Line types are specified by name. Valid names include:
<pre>
"solid"                 "dotted"
"dotdashed"             "shortdashed"
"longdashed"            "dotdotdashed"
"dotdotdotdashed"
</pre>
</td></tr>

<tr><td> linewidth </td><td> Real
</td><td>
</td></tr>

<tr><td> symbolsize </td><td> Real
</td><td>
</td></tr>

<tr><td> symbolkind </td><td> Char | String
</td><td>
Symbol types can be specified by name or by character.
If a character the font character is used as the plot symbol.
Valid symbol names include:
<pre>
"none"                  "filled circle"
"dot"                   "filled square"
"plus"                  "filled triangle"
"asterisk"              "filled diamond"
"circle"                "filled inverted triangle"
"cross"                 "filled fancy square"
"square"                "filled fancy diamond"
"triangle"              "half filled circle"
"diamond"               "half filled square"
"star"                  "half filled triangle"
"inverted triangle"     "half filled diamond"
"starburst"             "half filled inverted triangle"
"fancy plus"            "half filled fancy square"
"fancy cross"           "half filled fancy diamond"
"fancy square"          "octagon"
"fancy diamond"         "filled octagon"
</pre>
</td></tr>

<tr><td> textangle </td><td> Real
</td><td>
Rotate text counterclockwise by this number of degrees.
</td></tr>

<tr><td> texthalign </td><td> "left" <br> "center" <br> "right"
</td><td>
Where to horizontally anchor text strings.
</td></tr>

<tr><td> textvalign </td><td> "top" <br> "center" <br> "bottom"
</td><td>
Where to vertically anchor text strings.
</td></tr>

</table>

Config
------

Winston looks for the site-wide `winston.ini` configuration file
(located in the same directory as the winston source files) when it loads.
There are quite a few parameters in `winston.ini`, but most don't need
to be changed. Here's a few you might want to change:

### [default] ###

<table>
<tr><td> fontface </td><td> HersheySans
</td>
<td>

    Sets the default font face. `HersheySerif` or
    `HersheySans` is recommended if you have any TeX math-mode material.
</td>
</tr>

<tr><td> fontsize_min </td><td> 1.25
</td>
<td>

    Sets the minimum fontsize (relative to the size of the plotting window).
</td>
</tr>


<tr><td> symbolkind </td><td> diamond
</td>
<td>

    Sets the default symbol type.
</td>
</tr>

<tr><td> symbolsize </td><td> 2.0
</td>
<td>

    Sets the default symbol size.
</td>
</tr>
</table>

### [window] ###

<table>

<tr><td> width </td><td> 720 </td>
<td>
    The width (in pixels) of the X window produced by `x11()`.
</td>
</tr>

<tr><td> height </td><td> 540 </td>
<td>
    The height (in pixels) of the X window produced by `x11()`.
</td>
</tr>

<tr><td> reuse </td><td> true </td>
<td>
    Normally every invocation of `x11()` creates a new X window.
    This can be annoying during interactive use, so winston reuses the X window
    when it thinks it's not being called by a script.
    Set this to `no` to disable this behavior.
</td>
</tr>
</table>

----
