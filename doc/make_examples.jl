fn = "examples.md"
isfile(fn) && rm(fn)

for i = 1:6
    h = """
        Example $i
        ---------

        ![Example $i](http://www.cita.utoronto.ca/~nolta/julia/winston/examples/example$i.png)

        ``` julia"""
    run(`echo $h` >> fn)
    run(`cat ../examples/example$i.jl` >> fn)
    f = """
        ```
        """
    run(`echo $f` >> fn)
end

