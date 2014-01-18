export colormap

#Qualitative colormaps
########################   

#Standard palette
const set1 = [0x000000, 
              0xED2C30, 
              0x008C46, 
              0x1859A9,
              0xF37C21, 
              0x652B91, 
              0xA11C20, 
              0xB33794]
 
#default colors
function default_color(i::Int)
    cs = set1
    cs[mod1(i,length(cs))]
end

########################   

#data from matrix to RGB colors
function data2rgb{T<:Real}(data::AbstractArray{T,2}, limits::Interval, colormap)
    img = similar(data, Uint32)
    ncolors = length(colormap)
    limlower = limits[1]
    limscale = ncolors/(limits[2]-limits[1])
    for i = 1:length(data)
        datai = data[i]
        if isfinite(datai)
            idxr = limscale*(datai - limlower)
            idx = itrunc(idxr)
            idx += idxr > convert(T, idx)
            if idx < 1 idx = 1 end
            if idx > ncolors idx = ncolors end
            img[i] = colormap[idx]
        else
            img[i] = 0x00000000
        end
    end
    img
end

#####################

# from http://www.metastine.com/?p=7
function jetrgb(x)
    fourValue = 4x
    r = min(fourValue - 1.5, -fourValue + 4.5)
    g = min(fourValue - 0.5, -fourValue + 3.5)
    b = min(fourValue + 0.5, -fourValue + 2.5)
    RGB(clamp(r,0.,1.), clamp(g,0.,1.), clamp(b,0.,1.))
end

hsvrgb(x) = convert(RGB, Color.MSC(x*360))

#JetColormap() = Uint32[ convert(RGB24,jetrgb(i/256)) for i = 1:256 ]
#GrayColormap() = Uint32[ convert(RGB24,RGB(i/255,i/255,i/255)) for i = 0:255 ]

#####################
#Main function to handle colormaps
colormap() = (global _current_colormap; _current_colormap)
colormap(c::Array{Uint32,1}) = (global _current_colormap = c)
colormap(c::Array{RGB,1}) = colormap(Uint32[convert(RGB24, c[i]) for i = 1:length(c) ])
function colormap(name::String, n::Int=256; kvs...)
    if lowercase(name) == "jet"
        cm = [jetrgb(x) for x = linspace(0., 1., n)]
    elseif lowercase(name) == "hsv"
        cm = [hsvrgb(x) for x = linspace(0., 1., n)]
    else
        cm = Color.colormap(name, n; kvs...)
    end

    cm
end

#Default colormap
colormap("jet")