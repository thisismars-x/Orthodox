const std = @import("std");
const print = std.debug.print;

pub const BUFFER = []const u8;

pub const Emit = struct {

    // emit to this file, or emit to default_emit_path
    filename: ?[]const u8, 

    // collect include_directives from file
    collect_include_directives: bool,

    // permit all default_directives to be included when creating emit-file
    permit_default_directives: bool,

    // require llvm-emit (clang)
    require_llvm: bool,

    // which standard
    standard: u8,

    // found compiler backends
    avail_backends: std.ArrayList([]const u8),

    // use this compiler(changed when using with_llvm)
    use_backend: []const u8,

    // emits to this folder, if not avail creates anew
    const default_emit_path = "./emit/";

    // default standard(C++11)
    const default_standard = 11; 

    // search for these compiler backends
    // make sure these are in /usr/bin or are symlink-ed because
    // terminal invokes them by their names and not path
    const compiler_backends = [_][] const u8 {
        "clang++",
        "g++",
    };

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
    // returns compiler-name and compiler-path mapping
    pub fn find_compiler_backends() std.StringHashMap([]const u8) {
       
        var compiler_backend_list = std.StringHashMap([]const u8).init(Self.default_allocator);

        for(Self.compiler_backends) |backend| {
            const result = std.process.Child.run(.{
                .allocator = Self.default_allocator,
                .argv = &[_][]const u8{"which", backend},
            }) catch @panic("process.Child.run failed, terminal busy\n");

            if(result.stderr.len == 0) {
                compiler_backend_list.put(backend, result.stdout) catch @panic("could not put to compiler_backend_list\n");
            }
        }

        return compiler_backend_list;

    }

    // 
    // create a Emit to inform compiler on building emit-files
    pub fn with(filename: ?[]const u8, standard: ?u8) Self {

        var EmitFile: Emit = undefined;

        // Fill avail_backends
        EmitFile.avail_backends = std.ArrayList([]const u8).init(Self.default_allocator);
        const backends = find_compiler_backends();
        var iter = backends.iterator();
        
        if(backends.count() == 0) {
            print("ERR: NO COMPILER BACKEND FOUND\n", .{});
            std.process.exit(0);
        }

        while(iter.next()) |avail_backend| {
            EmitFile.avail_backends.append(avail_backend.key_ptr.*) catch @panic("could not append to EmitFile in ./InformedEmission.zig\n");
        }

        // emit-file name
        EmitFile.filename = filename;

        EmitFile.collect_include_directives = true;
        EmitFile.permit_default_directives = true;

        EmitFile.require_llvm = false;
        EmitFile.standard = standard orelse Self.default_standard;

        EmitFile.use_backend = EmitFile.avail_backends.items[0];

        return EmitFile;

    }

    //
    // when, llvm support is not secondary
    pub fn with_llvm(filename: ?[]const u8, standard: ?u8) Self {
        var EmitFile = with(filename, standard);
        EmitFile.require_llvm = true;

        for(EmitFile.avail_backends.items) |backend| {
            if(std.mem.eql(u8, backend, "clang++")) return EmitFile;
        }

        EmitFile.use_backend = "clang++";

        print("..no llvm support(did not find clang++ in terminal)\n", .{});
        print("..diagnostic: if you do not have clang++, install it\n", .{});
        print("..diagnostic: if you have clang++, symlink it to /usr/bin/\n", .{});
        print("..diagnostic: if you know any other backend, using llvm, update Emit struct in ./InformedEmission.zig\n", .{});
        std.process.exit(0);
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

};

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
