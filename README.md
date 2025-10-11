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
