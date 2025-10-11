# Orthodox

`Compiled, statically typed, simple language.`

```orthodox
Dear Lord, make it alright.
```

```orthodox
Orthodox:
    . supports numerical, string, and record types(enums/structs)
    . extensive typing, no untyped definitions
    . minimal, simple and extensive
    . works on all architectures supporting LLVM(clang)    
```
First looks:

```orthodox
//
// To run this program, save this file as 'exa.ox'
// and run 'orthodox exa.ox --run-immediate'
main :: proc() int {

    // this gets logged to stdout
    "Hello, ye, people of %s\n", "Mars";

    // const by default
    message :: String = "strings are awesome";

    // bit-constrained integer types
    // u8, i16, f32 ..... and so on
    NO_OF_DAYS_IN_A_WEEK :: u8 = 7;

    // mut- removes constness
    counter :: mut int = 0;

    for i in 0 : NO_OF_DAYS_IN_A_WEEK : {
        counter += 1;
    }

    if counter == 7 : {
        "properly counted\n";
    }

};
```

Installation:
```bash
# The Orthodox compiler, works on all Linux platforms
#
# Before preceeding with the installation, make sure to have
# at least zig 14.0 and the clang++ compiler toolchain.

# Installation
git clone https://github.com/thisismars-x/Orthodox.git
cd Orthodox
sudo ./install.sh
```

Some code:
```orthodox
main :: proc() int {

    number :: i32 = 2312142;
    if is_even(number) : {
        "number %d is even\n", number;
    }

    // ^ are pointers in Orthodox
    list_of_numbers :: ^mut i32;

    // #cast, is a compiler-directive that casts an expression to some type
    list_of_numbers = #cast (^mut i32)mAlloc(sizeof(number) * 8);

    for i in 0 : 8 : {
        list_of_numbers[i] = i + 1;
    }

    counter :: mut i32 = 0;

    // infinite loop
    loop : {
        "list_of_numbers[%d] = %d\n", counter, list_of_numbers[counter];

        counter += 1;
        if counter == 8 : { break; }
    }

};

//
// functions, just like struct and enum definitions get hoisted
// @ is the reference type in Orthodox
is_even :: proc(a :: @int) #bool {

    // Orthodox does not have boolean types
    // #bool is an alias to 'u8' expanded at compile time
    if a % 2 == 0 : {
        return #true;
    } else : {
        return #false;
    }

};

#alias u8  bool
#alias 0   false
#alias 1   true

```

Some more code:
```orthodox
//
// The magic of Orthodox comes from its interopterability with existing C(++) code.
// In simpler terms, Orthodox does not rely on an ABI, it is transpiled to C(++) code instead.
// The reason for this is: 'ANY EXISTING C(++) FRAMEWORK CAN BE USED WITH ORTHODOX FOR FREE'
//

// the same interface you would use in C(++), you can use in Orthodox
#include<cstdio>

//
// enums are typed with 'enum' keyword
level :: enum {
    LEVEL_0,
    LEVEL_1,
    LEVEL_2,
};

//
// structs are typed with 'struct' keyword
logger :: struct {
    lvl :: level,
    msg :: String,
};

main :: proc() int {

    lvl :: level = LEVEL_0;
    basic_logger :: mut logger;

    basic_logger.lvl = lvl;
    basic_logger.msg = "this is the message";

    print_logger(basic_logger);

};

print_logger :: proc(lg :: logger) void {

    if lg.lvl == LEVEL_0 : {
        "logger with LEVEL_0 ";
    } elif lg.lvl == LEVEL_1 : {
        "logger with LEVEL_1 ";
    } else : {
        "logger with LEVEL_2 ";
    }

    "%s\n", cStr(lg.msg);

};

```

Structure:
```orthodox
EXAMPLES                    ./examples/
COMPILER_INTERNALS_OVERVIEW ./compiler
GRAMMAR_DESCRIPTION         ./GrammarOrthodox
TOKEN_LIST                  ./tokens.zig
LEXER                       ./lexer.zig
ABSTRACT_SYNTAX_TREE        ./AST.zig
PARSER                      ./Parser.zig
SCOPE_CHECK                 ./ScopeLeakage.zig
COMPILER_DIRECTIVES         ./CompilerDirectives.zig
```
