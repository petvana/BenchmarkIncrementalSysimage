using GLMakie

xs = LinRange(0, 10, 100)
ys = LinRange(0, 15, 100)
zs = [cos(x) * sin(y) for x in xs, y in ys]

fig = surface(xs, ys, zs, axis=(type=Axis3,))

save("normal.png", fig)