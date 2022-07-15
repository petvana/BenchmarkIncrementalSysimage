module BenchmarkIncrementalSysimage

using LLVM_full_jll

export measure, compile

julia_dir = "julia"

julia_local = "/home/petr/software/julia/julia-petvana-fastsysimg-master"
if ispath(julia_local)
    julia_dir = julia_local
else
    # Download the specific branch of Julia, here 1.7.3 with incremental compilation of sysimage
    if !ispath(julia_dir)
        run(`git clone --depth 1 --branch pv/fastsysimg https://github.com/petvana/julia`)
    end
end

@show julia_dir

run(`make -j4 -C $julia_dir`)

julia_cmd = "$julia_dir/usr/bin/julia"
julia_sysimage = "$julia_dir/usr/lib/julia/sys.so"

chained_dir = "chained"

llvm_config = LLVM_full_jll.get_llvm_config_path()
objcopy = replace(llvm_config, "llvm-config" => "llvm-objcopy")
ar = replace(llvm_config, "llvm-config" => "llvm-ar")
clang = replace(llvm_config, "llvm-config" => "clang")
@show objcopy, ar, clang

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
    run(`$ar x sys-o.a`)
    run(`rm data.o`)
    run(`mv text.o text-old.o`)
    run(`$objcopy --remove-section .data.jl.sysimg_link text-old.o`) # rm the link between the native code and 
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
    run(`$ar x chained.o.a`) # Extract new sysimage files
    run(`ld --allow-multiple-definition -shared -o chained.so text.o data.o text-old.o`) # --allow-multiple-definition 
    cd("..")

    return time() - t_compile
end

end # module
