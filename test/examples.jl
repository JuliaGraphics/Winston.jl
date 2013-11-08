using Winston

# Each example will save a file. Put the file in a temporary directory,
# so they don't clutter up whatever directory this is being run from.
cwd = pwd()
# First we have to get the absolute path to the examples...
tls = task_local_storage()
dir = dirname(tls[:SOURCE_PATH])
direxample = normpath(joinpath(dir, "..", "examples"))
# Now switch to a temporary directory
dirdump = mktempdir()
cd(dirdump)

for i = 1:6
    include(joinpath(direxample, "example"*string(i)*".jl"))
    display(i == 3 ? t2 : p)
end

cd(cwd)
