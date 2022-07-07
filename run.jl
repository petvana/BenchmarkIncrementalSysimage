julia_dir = "julia"

# Download the specific branch of Julia, here 1.7.3 with incremental compilation of sysimage
if !ispath(julia_dir)
    run(`git clone --depth 1 --branch pv/kf/fastsysimg-1.7-use-precompile https://github.com/petvana/julia`)
end

if !ispath("$julia_dir/julia")
    #run(`make -j4 -C julia`)
end

julia_cmd = "julia/usr/bin/julia"
julia_sysimage = "julia/usr/lib/julia/sys.so"

chained_dir = "chained"

function measure(file, chained = false)
    t = time()
    image = chained ? "-J chained/chained.so" : ""
    work = isnothing(file) ? "-e \"\"" : "$file"
    txt = "$julia_cmd $image $work"
    run(Cmd(String.(split(txt))))
    return time() - t
end

function compile_chained(source_dir)
    t_run = measure("$source_dir/load.jl")
    println("Runned normal in $t_run")
    t_run = measure("$source_dir/load.jl")
    println("Runned normal in $t_run")
    t_run = measure("$source_dir/work.jl")
    println("Runned work in $t_run")

    # Compile the chained sysimage
    t_compile = time()
    mkpath(chained_dir)
    cd(chained_dir)
    cp("../julia/usr/lib/julia/sys-o.a", "sys-o.a", force=true)
    run(`ar x sys-o.a`)
    run(`rm data.o`)
    run(`mv text.o text-old.o`)
    run(`llvm-objcopy --remove-section .data.jl.sysimg_link text-old.o`) # rm the link between the native code and 
    cd("..")
    source_txt = "Base.__init_build(); include(\"$source_dir/load.jl\");"
    run(`$julia_cmd --sysimage-native-code=chained --sysimage=julia/usr/lib/julia/sys.so --output-o chained/chained.o.a -e $source_txt`)
    t_compile = time() - t_compile
    println("Compiled in $t_compile")

    cd(chained_dir)
    run(`ar x chained.o.a`) # Extract new sysimage files
    run(`ld --allow-multiple-definition -shared -o chained.so text.o data.o text-old.o`)
    cd("..")

    t_empty = measure(nothing, true)
    println("Run empty in $t_empty")

    t_load = measure("$source_dir/load.jl", true)
    println("Run load in $t_load")

    t_work = measure("$source_dir/work.jl", true)
    println("Run work in $t_work")
end

examples = Set(readdir("examples"))
delete!(examples, "GLMakie")

examples = ["OhMyREPL", "DataFrames", "GLMakie"]
#examples = ["Plots"]
#examples = ["GLMakie"]

for lib in examples# ["DataFrames", "OhMyREPL"]
    println(" --- $lib --- ")
    compile_chained(joinpath("examples/", lib))
end




    #=
time ../julia --sysimage=chained.so -e "print(\"Hello\")"
../julia --sysimage=chained.so
=#