////////////////////////////////////////////
//////// INFORMED EMISSION ////////////////
///////////////////////////////////////////

const std = @import("std");
const print = std.debug.print;

pub const BUFFER = []const u8;

pub const Emit = struct {

    // emit to this file, or emit to default_emit_path
    filename: []const u8, 

    // collect include_directives from file
    collect_include_directives: bool,

    // permit all default_directives to be included when creating emit-file
    permit_default_directives: bool,

    // include default_functions
    collect_default_functions: bool,

    // which standard
    standard: u8,

    // use this compiler(changed when using with_llvm)
    use_backend: []const u8,

    // c_header include list
    include_directives: std.ArrayList([]const u8),

    // default standard(C++11)
    const default_standard = 11; 

    // default_backend, if you switch to g++ you do not get llvm-mlir
    const default_backend = "clang++";

    // included by default in every emitted file
    const default_directives = [_][]const u8 {
        "cstdio",
        "cstdint",
        "array",
        "string",
    };

    const Self = @This();

    // 
    // clean this allocator when finished
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    const default_allocator = gpa.allocator();


    // 
    // create a Emit to inform compiler on building emit-files
    pub fn with(filename: []const u8, standard: u8) Self {

        var EmitFile: Emit = undefined;

        // emit-file name
        EmitFile.filename = filename;

        // collect_c_header, and add_default_directives
        EmitFile.collect_include_directives = true;
        EmitFile.permit_default_directives = true;

        // collect default functions from fn default_functions
        EmitFile.collect_default_functions = true;

        // cpp standard
        EmitFile.standard = standard; 

        // "clang++" default
        EmitFile.use_backend = Self.default_backend;

        EmitFile.include_directives = std.ArrayList([]const u8).init(Self.default_allocator);
        return EmitFile;

    }

    pub fn emit_default_headers(self: Self) BUFFER {
        _  = self;

        var emitted_code = std.ArrayList(u8).init(Self.default_allocator);

        for(Self.default_directives) |default_directive| {
            emitted_code.appendSlice("#include <") catch @panic("could not append to emitted_code in __emit_program\n");
            emitted_code.appendSlice(default_directive) catch @panic("could not append to emitted_code in __emit_program\n");
            emitted_code.appendSlice(">\n") catch @panic("could not append to emitted_code in __emit_program\n");
        }

        return emitted_code.toOwnedSlice() catch @panic("err owning slice pointed by emitted_code\n");

    }

    pub fn add_include_directives(self: *Self, directives: std.ArrayList([]const u8)) void {
        self.include_directives = directives;
    }

    // 
    // all default_functions are written here and are included in every file
    pub fn default_functions(self: *const Self) BUFFER {
        _ = self;
        var emitted_code = std.ArrayList(u8).init(Self.default_allocator);

        emitted_code.appendSlice(
        \\ 
        \\ // to change from std::string to c_str
        \\ const char* cStr(const string& str) {
        \\ return str.c_str(); 
        \\ }
        \\
        \\ void* mAlloc(size_t size) {
        \\    void* ptr = malloc(size);
        \\    if (!ptr) {
        \\        fprintf(stderr, "malloc failed for %zu bytes\n", size);
        \\        exit(EXIT_FAILURE);
        \\    }
        \\    return ptr;
        \\ }
        \\
        ) catch @panic("could not appendSlice to emitted_code in default_functions\n");

        return emitted_code.toOwnedSlice() catch @panic("err owning slice pointed by emitted_code\n");
    }

};

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////// INFORMED EMISSION TESTS //////////////////// INFORMED EMISSION TESTS //////////////////// INFORMED EMISSION TESTS ////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// test {
//     print("..find compiler backends\n", .{});
//
//     const backends = Emit.find_compiler_backends();
//     if(backends.count() != 0) {
//         print("..compilers found\n", .{});
//
//         var iter = backends.iterator();
//         while(iter.next()) |compiler| {
//             print("{s} = {s}", .{compiler.key_ptr.*, compiler.value_ptr.*});
//         }
//
//         print("..passed\n\n", .{});
//     } 
//     else print("..no compilers found\n", .{});
// }
//
// test {
//     print("..create emit file\n", .{});
//
//     const file = Emit.with_llvm("this.cpp", 11);
//     _ = file;
//     print("..passed\n", .{});
// }
