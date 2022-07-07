using DataFrames

df = DataFrame()
push!(df, (a = 1, b = 1.0, c = "c", d = 0x0))
str = "$df"
