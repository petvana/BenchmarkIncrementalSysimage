using DataFrames
using PrettyTables

julia_dir = "julia"

julia_local = "/home/petr/software/julia/julia-petvana-fastsysimg-master"
if ispath(julia_local)
    julia_dir = julia_local
else
    # Download the specific branch of Julia, here 1.7.3 with incremental compilation of sysimage
    if !ispath(julia_dir)
        run(`git clone --depth 1 --branch pv/kf/fastsysimg-1.7-use-precompile https://github.com/petvana/julia`)
    end
end

@show julia_dir

run(`make -j4 -C $julia_dir`)

julia_cmd = "$julia_dir/usr/bin/julia"
julia_sysimage = "$julia_dir/usr/lib/julia/sys.so"

chained_dir = "chained"

function measure(file, chained = false, precompiles = false)
    t = time()
    image = chained ? "-J chained/chained.so" : ""
    work = isnothing(file) ? "-e \"\"" : "$file"
    prec = precompiles ? " --trace-compile=statements.txt" : ""
    txt = "$julia_cmd $image $prec $work"
    run(Cmd(String.(split(txt))))
    return time() - t
end

function compile(file)
    t_compile = time()
    mkpath(chained_dir)
    cd(chained_dir)
    cp("$julia_dir/usr/lib/julia/sys-o.a", "sys-o.a", force=true)
    run(`ar x sys-o.a`)
    run(`rm data.o`)
    run(`mv text.o text-old.o`)
    run(`llvm-objcopy --remove-section .data.jl.sysimg_link text-old.o`) # rm the link between the native code and 
    cd("..")

    source_txt = """

Base.__init_build(); 
module PrecompileStagingArea;
include(\"$file\");
end;
@ccall jl_precompiles_for_sysimage(1::Cuchar)::Cvoid;
include("precompile.jl")
    """

    run(`$julia_cmd --sysimage-native-code=chained --sysimage=$julia_dir/usr/lib/julia/sys.so --output-o chained/chained.o.a -e $source_txt`)

    cd(chained_dir)
    run(`ar x chained.o.a`) # Extract new sysimage files
    run(`ld --allow-multiple-definition -shared -o chained.so text.o data.o text-old.o`)
    cd("..")

    return time() - t_compile
end

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

    # Compile the chained sysimage
    run(`rm -f statements.txt`)
    t_compile = compile("$source_dir/load.jl")
    println("Compiled in $t_compile")

    t_empty = measure(nothing, true)
    println("Run empty in $t_empty")

    t_load = measure("$source_dir/load.jl", true)
    println("Run load in $t_load")

    t_work = measure("$source_dir/work.jl", true, true)
    println("Run work in $t_work")

    try
        # Compile the chained sysimage
        t_compile = compile("$source_dir/load.jl")
        println("Compiled in $t_compile")
    
        t_empty = measure(nothing, true)
        println("Run empty in $t_empty")
    
        t_load = measure("$source_dir/load.jl", true)
        println("Run load in $t_load")
    
        t_work = measure("$source_dir/work.jl", true)
        println("Run work in $t_work")
    catch
    end

    push!(df, (
        library = splitpath(source_dir)[end],
        N_empty = t_nempty,
        N_load = t_nload,
        N_work = t_nwork,
        Compile = t_compile,
        S_empty = t_empty, 
        S_load = t_load,
        S_work = t_work,
    ))
end

examples = Set(readdir("examples"))
delete!(examples, "GLMakie")

#examples = ["OhMyREPL"]
examples = ["OhMyREPL", "DataFrames", "Plots", "GLMakie"]

for lib in examples# ["DataFrames", "OhMyREPL"]
    println(" --- $lib --- ")
    compile_chained(joinpath("examples/", lib))
    #break
end

@show df
df[:, 2:end] = round.(df[:, 2:end], digits = 2)

pretty_table(df, tf = tf_markdown)


    #=
time ../julia --sysimage=chained.so -e "print(\"Hello\")"
../julia --sysimage=chained.so
=#
