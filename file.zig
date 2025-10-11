const std = @import("std");
const print = std.debug.print;

pub fn find_compiler_backends() std.StringHashMap([]const u8) {
    
    const search_backends = [_][]const u8 {
        "g++",
        "clang++",
    };


    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    const allocator = gpa.allocator();

    var compiler_backend_list = std.StringHashMap([]const u8).init(allocator);

    for(search_backends) |backend| {
        const result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{"which", backend},
        }) catch @panic("process.Child.run failed, terminal busy\n");

        if(result.stderr.len == 0) {
            compiler_backend_list.put(backend, result.stdout) catch @panic("could not put to compiler_backend_list\n");
        }
    }

    return compiler_backend_list;


}

pub fn main() !void {
    // Create a new file named "example.txt"
    // The second argument is a File.OpenFlags struct, which can be empty for default behavior
    var file = try std.fs.cwd().createFile("example.txt", .{});
    defer file.close(); // Ensure the file is closed when exiting the function

    // Data to write to the file
    const data_to_write = "Hello, Zig file writing!\n";

    // Write the data to the file
    try file.writeAll(data_to_write);

    std.debug.print("Successfully wrote to example.txt\n", .{});
}
