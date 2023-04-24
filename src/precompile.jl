using PrecompileTools 

@setup_workload begin
    @compile_workload begin
      p=plot(1:10)
      imagesc(rand(5,5))
    end
end