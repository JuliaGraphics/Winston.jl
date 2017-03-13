using Compat; import Compat.String

_winston_config = Inifile()

begin
    local fn
    for dir in [".";Pkg.dir();LOAD_PATH]
        fn = joinpath(dir, "Winston.ini")
        if isfile(fn) break end
        fn = joinpath(dir, "Winston", "src", "Winston.ini")
        if isfile(fn) break end
    end
    read(_winston_config, fn)
end

if VERSION < v"0.4-"
    split_keep_false(a, b) = split(a, b, false)
else
    split_keep_false(a, b) = split(a, b, keep=false)
end

function _atox(s::AbstractString)
    x = strip(s)
    if x == "nothing"
        return nothing
    elseif x == "true"
        return true
    elseif x == "false"
        return false
    elseif length(x) > 2 && lowercase(x[1:2]) == "0x"
        try
            h = parse(Int, x[3:end], 16)
            return h
        end
    elseif x[1] == '{' && x[end] == '}'
        style = Dict{Symbol,Any}()
        pairs = map(strip, split_keep_false(x[2:end-1], ','))
        for pair in pairs
            kv = split_keep_false(pair, ':')
            style[ Symbol(strip(kv[1])) ] = _atox(strip(kv[2]))
        end
        return style
    elseif x[1] == '"' && x[end] == '"'
        return x[2:end-1]
    end
    if ismatch(r"^[+-]?\d+$",x)
        return parse(Int,x)
    end
    r  = tryparse(Float64, x)
    isnull(r) ? x : get(r)
end

function config_value(section, option)
    strval = get(_winston_config, section, option, "nothing")
    _atox(strval)
end

function config_options(sec::AbstractString)
    opts = Dict{Symbol,Any}()
    if sec == "defaults"
        for (k,v) in _winston_config.defaults
            opts[Symbol(k)] = _atox(v)
        end
    elseif has_section(_winston_config, sec)
        for (k,v) in section(_winston_config, sec)
            opts[Symbol(k)] = _atox(v)
        end
    end
    opts
end

