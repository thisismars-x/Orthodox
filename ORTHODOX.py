# +----------------------------------
#
# Orthodox CLI
#
# +----------------------------------

import argparse, subprocess, sys, os

orthodox_cli = argparse.ArgumentParser(description="Orthodox.")

orthodox_cli.add_argument("input_file", help="input file name")
orthodox_cli.add_argument("-o", "--output", help="output <optional> file name", metavar="file")

orthodox_cli.add_argument("--emit-llvm", help="emit llvm-mlir, <requires> clang++", action="store_true")
orthodox_cli.add_argument("--emit-cpp", help="emit c++ code", action="store_true")

orthodox_cli.add_argument("-l", help="link against .so, .a libs", metavar="lib", action="append")
orthodox_cli.add_argument("-std", help="language standard", metavar="c++<std>")

args = orthodox_cli.parse_args()


# mirror of ./CodeGen.zig's __main_emit_program
def __main_emit_program(input_file: str):
    cmd = ["zig", "run", "CodeGen.zig", "--", input_file]
    result = subprocess.run(cmd)

    if(result.stderr):
        print("....failed ./CodeGen.zig:: __main_emit_program")
        print("....diagnostic::")
        print("....error during Orthodox -> c++ translation")
        sys.exit(-1)

__main_emit_program(args.input_file)


# never name a file ORTHODOX_TRANSIT_FILE, this is intermediate file produced
# before machine/llvm code
ORTHODOX_TRANSIT_FILE = "ORTHODOX_TRANSIT_FILE.cpp"

# compiles ORHTHODOX_TRANSIT_FILE
def __compile_down():
    cmd = ["clang++", ORTHODOX_TRANSIT_FILE]
    if(args.output):
        cmd.append("-o")
        cmd.append(args.output)

    if(args.emit_llvm):
        cmd.append("-c")
        cmd.append("-emit-llvm")

    if(args.std):
        cmd.append(f"-std={args.std}")

    result = subprocess.run(cmd)

    if(args.emit_cpp):
        filename = args.input_file.split(".")
        filename = f"{filename[0]}.cpp"
        os.rename(ORTHODOX_TRANSIT_FILE, filename)


    if(result.stderr):
        print("....failed when compiling from c++")
        print("....diagnostic::")
        print("....Orthodox provides no type safety, and translates invariably to C++")
        print("....invoked command::")
        for x in cmd: print(x, end=" ")


__compile_down()

