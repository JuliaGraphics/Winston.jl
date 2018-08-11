_winston_config = Inifile()

begin
    local fn
    for dir in [".";@__DIR__;LOAD_PATH]
        fn = joinpath(dir, "Winston.ini")
        if isfile(fn) break end
        fn = joinpath(dir, "Winston", "src", "Winston.ini")
        if isfile(fn) break end
    end
    read(_winston_config, fn)
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
            h = parse(Int, x[3:end], base=16)
            return h
        catch
        end
    elseif x[1] == '{' && x[end] == '}'
        style = Dict{Symbol,Any}()
        pairs = map(strip, split(x[2:end-1], ',', keepempty=false))
        for pair in pairs
            kv = split(pair, ':', keepempty=false)
            style[ Symbol(strip(kv[1])) ] = _atox(strip(kv[2]))
        end
        return style
    elseif x[1] == '"' && x[end] == '"'
        return x[2:end-1]
    end
    if occursin(r"^[+-]?\d+$", x)
        return parse(Int, x)
    end
    r = tryparse(Float64, x)
    @static if VERSION < v"0.7.0-DEV.3017"
        return isnull(r) ? x : get(r)
    else
        return r === nothing ? x : r
    end
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
