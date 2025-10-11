#! /usr/bin/python

# +----------------------------------
#
# Orthodox CLI
#
# +----------------------------------

import argparse, subprocess, sys, os

orthodox_cli = argparse.ArgumentParser(
    prog="orth",
    description="The Orthodox language."
)

orthodox_cli.add_argument("input_file", help="input file name")
orthodox_cli.add_argument("-o", "--output", help="output <optional> file name", metavar="file")

orthodox_cli.add_argument("--emit-llvm", help="emit llvm-mlir, <requires> clang++", action="store_true")
orthodox_cli.add_argument("--emit-cpp", help="emit c++ code", action="store_true")

orthodox_cli.add_argument("-l", help="link against .so, .a libs", metavar="lib", action="append")
orthodox_cli.add_argument("-std", help="language standard", metavar="c++<std>")

orthodox_cli.add_argument("--run-immediate", "-ri", help="compile, and run immediately", action="store_true")

# send this flags directly to clang++
orthodox_cli.add_argument("-m", "--more", help="send this message to underlying backend directly", metavar="TOCOMPILERBACKEND")

args = orthodox_cli.parse_args()


# mirror of ./CodeGen.zig's __main_emit_program
def __main_emit_program(input_file):
    cmd = ["orth", input_file]
    result = subprocess.run(cmd)

# never name a file ORTHODOX_TRANSIT_FILE, this is intermediate file produced
# before machine/llvm code
ORTHODOX_TRANSIT_FILE = "ORTHODOX_TRANSIT_FILE.cpp"

# compiles ORHTHODOX_TRANSIT_FILE
def __compile_down():
    cmd = ["clang++", ORTHODOX_TRANSIT_FILE]
    
    if(not args.output):
        args.output = "a.out"

    cmd.append("-o")
    cmd.append(args.output)

    if(args.emit_llvm):
        cmd.append("-c")
        cmd.append("-emit-llvm")

    if(args.std):
        cmd.append(f"-std={args.std}")

    if(args.more):
        cmd.append(args.more)

    # is ORHTHODOX_TRANSIT_FILE present?
    if os.path.exists(ORTHODOX_TRANSIT_FILE):
        
        if(os.path.exists(args.output)):
            os.remove(args.output)

        result = subprocess.run(cmd)

        if(args.emit_cpp):
            filename = args.input_file.split(".")
            filename = f"{filename[0]}.cpp"
            os.rename(ORTHODOX_TRANSIT_FILE, filename)
        else:
            os.remove(ORTHODOX_TRANSIT_FILE)

        # run-immediately after compilation
        if(args.run_immediate):
            if os.path.exists(args.output):
                subprocess.run([f"./{args.output}"])
                # then delete it
                os.remove(args.output)

            else:
                print("")
                print(f"........orthodox-error")
                print(f"........ran command ./{args.output}")
                print(f"........but no file with name {args.output}")
   


__main_emit_program(args.input_file)
__compile_down()

