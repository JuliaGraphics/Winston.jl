
_winston_config = Inifile()

begin
    local fn
    for dir in [".",Pkg.dir(),LOAD_PATH]
        fn = joinpath(dir, "Winston.ini")
        if isfile(fn) break end
        fn = joinpath(dir, "Winston", "src", "Winston.ini")
        if isfile(fn) break end
    end
    read(_winston_config, fn)
end

function _atox(s::String)
    x = strip(s)
    if x == "nothing"
        return nothing
    elseif x == "true"
        return true
    elseif x == "false"
        return false
    elseif length(x) > 2 && lowercase(x[1:2]) == "0x"
        try
            h = parseint(x[3:end], 16)
            return h
        end
    elseif x[1] == '{' && x[end] == '}'
        style = Dict{Symbol,Any}()
        pairs = map(strip, split(x[2:end-1], ',', false))
        for pair in pairs
            kv = split(pair, ':', false)
            style[ symbol(strip(kv[1])) ] = _atox(strip(kv[2]))
        end
        return style
    elseif x[1] == '"' && x[end] == '"'
        return x[2:end-1]
    end
    if ismatch(r"^[+-]?\d+$",x)
        return int(x)
    end
	out = Array(Float64,1)
    if float64_isvalid(x, out)
        return out[1]
    end
    return x
end

function config_value(section, option)
    strval = get(_winston_config, section, option, "nothing")
    _atox(strval)
end

function config_options(sec::String)
    opts = Dict{Symbol,Any}()
    if sec == "defaults"
        for (k,v) in _winston_config.defaults
            opts[symbol(k)] = _atox(v)
        end
    elseif has_section(_winston_config, sec)
        for (k,v) in section(_winston_config, sec)
            opts[symbol(k)] = _atox(v)
        end
    end
    opts
end

