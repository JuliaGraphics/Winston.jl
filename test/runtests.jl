tests = ["compare.jl",
         "crashes.jl",
         "examples.jl",
         "issues.jl",
         "plot.jl"]

println("Running tests:")

for curtest in tests
    println(" Test: $(curtest)")
    include(curtest)
end
