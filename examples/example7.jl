using Winston

n = 300
x = linspace(-10., 10., n)
t = linspace(-1., 1., n)
z = (3. + 4*cosh(2x' .- 8t) + cosh(4x' .- 64t)) ./
    (3*cosh(x' .- 28t) + cosh(3x' .- 36t)) .^ 2

t = Table(2,2)
t[1,1] = imagesc(z, (minimum(z),0.6maximum(z)))

p = imagesc(z)
xlim(0, 1000)
ylim(400, 0)
t[2,1] = p

p = imagesc(z)
xlim(0, 1000)
ylim(0, 400)
t[1,2] = p

file(t, "example7.png")
