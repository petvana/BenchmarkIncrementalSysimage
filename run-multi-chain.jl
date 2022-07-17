module Run

using DataFrames
using PrettyTables

push!(LOAD_PATH, pwd())

using BenchmarkIncrementalSysimage

df = DataFrame()

function compile_chained(source_dir)
    t_nempty = measure(nothing)
    println("Run empty in $t_nempty")
    t_nload = measure("$source_dir/load.jl")
    println("Runned normal in $t_nload")
    t_nload = measure("$source_dir/load.jl")
    println("Runned normal in $t_nload")
    t_nwork = measure("$source_dir/work.jl")
    println("Runned work in $t_nwork")
    t_nwork = measure("$source_dir/work.jl")
    println("Runned work in $t_nwork")

    t_compile = t_compile2 = t_empty = t_load = t_work = NaN

    # Compile the chained sysimage
    run(`rm -f statements.txt`)
    t_compile = compile("$source_dir/load.jl")
    println("Compiled in $t_compile")

    # measure(nothing, true)
    # println("Run empty in $t_empty")

    # measure("$source_dir/load.jl", true)
    # println("Run load in $t_load")

    t_work_tmp = measure("$source_dir/work.jl", true, true)
    println("Run work in $t_work_tmp")

    #try
        # Compile the chained sysimage
        cp("chained/chained.so", "chained/chained1.so", force=true)

        t_compile2 = compile(nothing; original_sysimage = "chained/chained1.so", generated_sysimage = "chained.so")
        println("Compiled2 in $t_compile2")
    
        t_empty = measure(nothing, true)
        println("Run empty in $t_empty")
    
        t_load = measure("$source_dir/load.jl", true)
        println("Run load in $t_load")
    
        t_work = measure("$source_dir/work.jl", true)
        println("Run work in $t_work")
    #catch
    #end

    push!(df, (
        library = splitpath(source_dir)[end],
        N_empty = t_nempty,
        N_load = t_nload,
        N_work = t_nwork,
        Compile = t_compile,
        Compile2 = t_compile2,
        S_empty = t_empty, 
        S_load = t_load,
        S_work = t_work,
    ))
end

examples = Set(readdir("examples"))
delete!(examples, "GLMakie")

#examples = ["OhMyREPL"]
examples = ["OhMyREPL", "DataFrames", "Plots", "GLMakie"]
#examples = ["OhMyREPL", "DataFrames"]

for lib in examples
    println(" --- $lib --- ")
    compile_chained(joinpath("examples/", lib))
    #break
end

@show df
df[:, 2:end] = round.(df[:, 2:end], digits = 2)

pretty_table(df, tf = tf_markdown)

end
