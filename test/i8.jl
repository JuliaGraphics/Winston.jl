require("Winston/src/Plot")
using Plot
large = [i^4 + 1e12 for i in 1:10^3]
small = [1:10^3]
p = plot(small,large)
