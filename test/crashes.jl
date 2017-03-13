# make sure the following examples don't crash

using Winston

println("Testing that bad inputs don't cause a crash...")

# bad ranges
display(plot(1:10, xlog=true, xrange=(-10,10)))
display(plot(1:10, ylog=true, yrange=(-10,10)))

# no data in range
display(plot(1:4, xrange=(-10,-3)))
display(loglog(-10:-4))

# only a single point
display(plot([1]))
display(loglog([1]))

# empty table cells
t = Table(2,2)
t[1,1] = plot(1:3)
display(t)

# row & col vectors
x = 1:10
y = 1:10
display(plot(x',y'))
display(plot(x'',y''))

println("Done testing bad inputs")
