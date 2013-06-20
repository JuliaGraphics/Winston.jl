
_winston_config = IniFile()

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
        style = Dict()
        pairs = map(strip, split(x[2:end-1], ',', false))
        for pair in pairs
            kv = split(pair, ':', false)
            style[ strip(kv[1]) ] = _atox(strip(kv[2]))
        end
        return style
    elseif x[1] == '"' && x[end] == '"'
        return x[2:end-1]
    end
    try
        i = int(x)
        return i
    end
    try
        f = float(x)
        return f
    end
    return x
end

function config_value(section, option)
    strval = get(_winston_config, section, option, "nothing")
    _atox(strval)
end

function config_options(sec::String)
    opts = Dict()
    if sec == "defaults"
        for (k,v) in _winston_config.defaults
            opts[k] = _atox(v)
        end
    elseif has_section(_winston_config, sec)
        for (k,v) in section(_winston_config, sec)
            opts[k] = _atox(v)
        end
    end
    opts
end

