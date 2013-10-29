Getting started
===============

Winston offers an easy to use `plot` command to create figures and `oplot` command to overplot into already existing figures. After Winston is loaded by typing the `using Winston`, the most basic plot can be created by just writing
```julia
plot(x,y)
```
To add something to this, use
```
oplot(x2,y2)
```
And finally save it with
```julia
file("figure.png")
```

More fancy figures can be created by using the quick-option for line/symboltype and color
```julia
plot(x,y,"r--")
```
This creates a red dashed curve. Abbreviations for colors and line/symboltypes are same as in pythons matplotlib. The `plot` command can also take more then one set of vectors and style options, like this
```julia
plot(x,y,"r--",x2,y2,"g^")
```

For even more awesome figures we can use the named variables like this
```julia
plot(x,y,symboltype="filled circle",color=0xcc0000,xrange=[10,100],xlog=true)
```
All the named variables are same as in Winston itself. List can be found from [Winston reference sheet](https://github.com/nolta/Winston.jl/blob/master/doc/reference.md)


Managing multiple figures
=========================

There is also a more advanced option to overplot into a different figures and save other figures then the most current one. This can be done like this

```julia
using Winston

x=linspace(0,10,100)
y=cos(x)
y2=sin(x)
y3=e.^(-x)
y4=e.^(-2x)
y5=e.^(-3x)

plot(x,y,"--b",x,y2,"-g") #creates the first figure
p=oplot(x,y3,";k") #overplot to it and save into p

p2=plot(x,y3,"^r") #create second figure

oplot(p,x,y4,"-r") #creates third fig by overplotting into p
p3=oplot(x,y5,"-g") #overplot into this and save into p3

file(p,"oplot_test1.png") #save p
file(p2,"oplot_test2.png") #save p2
file(p3,"oplot_test3.png") #save p3
file("oplot_test4.png") #save last fig i.e. p3

plot(p2,x,y5,"vk") #Make new fig that overplots to p2
file("oplot_test5.png") #save it
```

Other functions
===============
In addition to `plot` & `oplot`, there exists a few shortcuts for commonly used things.

```julia
semilogx(x,y,args,kwargs)
```
Logarithmic x-axis. This is the same as writing `plot(x,y,args,xlog=true,kwargs)`.

```julia
semilogy(x,y,args,kwargs)
```
Logarithmic y-axis. This is the same as writing `plot(x,y,args,ylog=true,kwargs)`.

```julia
loglog(x,y,args,kwargs)
```
Logarithmic x- and y-axis. This is the same as writing `plot(x,y,args,xlog=true,ylog=true,kwargs)`.

```julia
fillbetween(xA,yA,xB,yB,kwargs)
```
Fill the area between xA & yA and xB & yB. To change the color of the area, use the named argument `color=XXX`.

```julia
spy(M)
```
Plots the sparsity pattern of any matrix M.


Examples
========

Example 1
---------
![Example 1](http://www.cita.utoronto.ca/~nolta/julia/winston/examples/example1.png)

```julia
using Winston

x=linspace(0,3pi,100)
c=cos(x)
s=sin(x)

plot(x,c,"r-",x,s,"-b",title="title!",xlabel="\\Sigma x^2_i",ylabel="\\Theta_i")
fillbetween(x,c,x,s)

file("example1_2.png")
```
Example 2
---------
![Example 2](http://www.cita.utoronto.ca/~nolta/julia/winston/examples/example2.png)

```julia
using Winston

n = 21
x = linspace( 0, 100, n )
yA = 40 + 10randn(n)
yB = x + 5randn(n)

plot(x,yA,symboltype="circle",xrange=[0,100],yrange=[0,100],aspect_ratio=1)
oplot(x,yB,symboltype="filled circle")
oplot([0,100],[0,100],linetype="dotted")

file("example2_2.png")
```

Example 3
---------

Example 4
---------

Example 6
---------