using SnoopPrecompile 

@precompile_setup begin
    @precompile_all_calls begin
      p=plot(1:10)
      imagesc(rand(5,5))
    end
end