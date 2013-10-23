#Showing examples of how the plot()/oplot() -functions work.
#These are not meant to be neat looking figures.
  
using Winston

println("Winston loaded...")

x=linspace(0,10,100)
y=cos(x)
y2=sin(x)
y3=e.^(-x)
y4=e.^(-2x)
y5=e.^(-3x)

#basic tests
###############
#plot(x,y3,"-r",yrange=[1.0,2.0e4],ylog=true,linewidth=5.,draw_spine=false)
#loglog(x,y3,"-rd",xrange=[1,10],yrange=[1.0,2.0e4],linewidth=5.)

#overplot behaviour
###############
plot(x,y,"--b",x,y2,"-g") #creates first figure
p=oplot(x,y3,";k") #overplot to it and save into p

p2=plot(x,y3,"^r") #create second figure

oplot(p,x,y4,"-r") #creates third fig by overplotting into p
p3=oplot(x,y5,"-g") #overplot into this and save into p3

file(p,"oplot_test.png") #save p
file(p2,"oplot_test2.png") #save p2
file(p3,"oplot_test3.png") #save p3
file("oplot_testw.png") #save last fig i.e. p3

p2=plot(p2,x,y5,"vk") #oplot to p2
file(p2,"oplot_test4.png") #save new p2
file("oplot_testw2.png") #save last fig i.e. p2