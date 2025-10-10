/////////////////////////////////////////
//////// COMPILER - DIRECTIVES /////////
////////////////////////////////////////

// +------------------------------------------------+
// Compiler Directives are expanded at compile time
// and provide functionality for
//   . aliases
//   . imports
//   . cincludes
// +-----------------------------------------------+  

const std = @import("std");

//
// aliases of the form #alias <src> <target> are expanded before parsing
pub fn __expand_aliases(source: []const u8, default_allocator: std.mem.Allocator) []u8 {

    var aliases = std.StringHashMap([]const u8).init(default_allocator);
    defer aliases.deinit();

    var it = std.mem.tokenizeAny(u8, source, "\n");
    while (it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        if (std.mem.startsWith(u8, trimmed, "#alias")) {
            var parts = std.mem.tokenizeScalar(u8, trimmed, ' ');
            _ = parts.next(); // skip "#alias"

            const target = parts.next() orelse continue;
            const name = parts.next() orelse continue;

            aliases.put(name, target) catch @panic("could not 'put' to aliases in __expand_aliases\n");
        }
    }

    var result = std.ArrayList(u8).init(default_allocator);
    defer result.deinit();

    var i: usize = 0;
    var in_string = false;
    var in_comment = false;

    while (i < source.len) {
        const c = source[i];

        // consume alias definitions
        if (!in_string and !in_comment and std.mem.startsWith(u8, source[i..], "#alias")) {
            while (i < source.len and source[i] != '\n') : (i += 1) {}
            if (i < source.len) i += 1; 
            continue;
        }

        if (!in_string and !in_comment and i + 1 < source.len and source[i] == '/' and source[i + 1] == '/') {
            in_comment = true;
            result.append(c) catch @panic("could not append to result in __expand_aliases\n");
            i += 1;
            result.append(source[i]) catch @panic("could not append to result in __expand_aliases\n");
            i += 1;
            continue;
        }

        if (in_comment and c == '\n') {
            in_comment = false;
        }

        if (!in_comment and (c == '"' or c == '\'')) {
            in_string = !in_string;
            result.append(c) catch @panic("could not append to result in __expand_aliases\n");
            i += 1;
            continue;
        }

        if (in_string or in_comment) {
            result.append(c) catch @panic("could not append to result in __expand_aliases\n");
            i += 1;
            continue;
        }

        if (c == '#' and i + 1 < source.len and std.ascii.isAlphabetic(source[i + 1])) {
            const start = i + 1;
            var end = start;
            while (end < source.len and (std.ascii.isAlphanumeric(source[end]) or source[end] == '_')) {
                end += 1;
            }
            const name = source[start..end];
            if (aliases.get(name)) |target| {
                result.appendSlice(target) catch @panic("could not append to result in __expand_aliases\n");
                i = end;
                continue;
            }
        }

        result.append(c) catch @panic("could not append to result in __expand_aliases\n");
        i += 1;
    }

    return result.toOwnedSlice() catch @panic("could not own the slice pointed to by result\n");
}


//
// includes_list contains of C_headers that we desire to bind with during compilation
pub fn __extract_includes(source: []const u8, default_allocator: std.mem.Allocator) 
    struct {
        code: []u8, // source_code
        includes: std.ArrayList([]const u8), // list of include_headers
    }
{

    var includes = std.ArrayList([]const u8).init(default_allocator);
    var result = std.ArrayList(u8).init(default_allocator);

    var i: usize = 0;
    var in_string = false;
    var in_comment = false;

    while (i < source.len) {
        const c = source[i];

        if (!in_string and !in_comment and std.mem.startsWith(u8, source[i..], "#include")) {
            i += "#include".len;
            while (i < source.len and std.ascii.isWhitespace(source[i])) : (i += 1) {}

            const start_char = if (i < source.len) source[i] else 0;
            if (start_char == '"' or start_char == '<') {
                i += 1;
                const start_name = i;
                const end_char: u8 = if (start_char == '"') '"' else '>';
                while (i < source.len and source[i] != end_char) : (i += 1) {}
                const header_name = source[start_name..i];
                includes.append(header_name) catch @panic("could not append to includes in __extract_includes\n");
                if (i < source.len) i += 1; // skip closing " or >
            }

            while (i < source.len and source[i] != '\n') : (i += 1) {}
            if (i < source.len) i += 1; // skip newline
            continue;
        }

        if (!in_string and !in_comment and i + 1 < source.len and source[i] == '/' and source[i + 1] == '/') {
            in_comment = true;
            result.append(c) catch @panic("could not append to result in __extract_includes\n");
            i += 1;
            result.append(source[i]) catch @panic("could not append to result in __extract_includes\n");
            i += 1;
            continue;
        }

        if (in_comment and c == '\n') {
            in_comment = false;
        }

        if (!in_comment and (c == '"' or c == '\'')) {
            in_string = !in_string;
            result.append(c) catch @panic("could not append to result in __extract_includes\n");
            i += 1;
            continue;
        }

        if (in_string or in_comment) {
            result.append(c) catch @panic("could not append to result in __extract_includes\n");
            i += 1;
            continue;
        }

        result.append(c) catch @panic("could not append to result in __extract_includes\n");
        i += 1;
    }

    return .{
        .code = result.toOwnedSlice() catch @panic("could not own result in __extract_includes\n"),
        .includes = includes,
    };
}

// 
// imports_list is a list of Orthodox files to bind with during compilation
pub fn __extract_imports(source: []const u8, default_allocator: std.mem.Allocator) 
    struct {
        code: []u8, // source_code
        imports: std.ArrayList([]const u8), // list of imports_Orthodox
    }
{

    var imports = std.ArrayList([]const u8).init(default_allocator);
    var result = std.ArrayList(u8).init(default_allocator);

    var i: usize = 0;
    var in_string = false;
    var in_comment = false;

    while (i < source.len) {
        const c = source[i];

        if (!in_string and !in_comment and std.mem.startsWith(u8, source[i..], "#import")) {
            i += "#import".len;
            while (i < source.len and std.ascii.isWhitespace(source[i])) : (i += 1) {}

            const start_char = if (i < source.len) source[i] else 0;
            if (start_char == '"' or start_char == '<') {
                i += 1;
                const start_name = i;
                const end_char: u8 = if (start_char == '"') '"' else '>';
                while (i < source.len and source[i] != end_char) : (i += 1) {}
                const header_name = source[start_name..i];
                imports.append(header_name) catch @panic("could not append to imports in __extract_imports\n");
                if (i < source.len) i += 1; // skip closing " or >
            }

            while (i < source.len and source[i] != '\n') : (i += 1) {}
            if (i < source.len) i += 1; // skip newline
            continue;
        }

        if (!in_string and !in_comment and i + 1 < source.len and source[i] == '/' and source[i + 1] == '/') {
            in_comment = true;
            result.append(c) catch @panic("could not append to result in __extract_imports\n");
            i += 1;
            result.append(source[i]) catch @panic("could not append to result in __extract_imports\n");
            i += 1;
            continue;
        }

        if (in_comment and c == '\n') {
            in_comment = false;
        }

        if (!in_comment and (c == '"' or c == '\'')) {
            in_string = !in_string;
            result.append(c) catch @panic("could not append to result in __extract_imports\n");
            i += 1;
            continue;
        }

        if (in_string or in_comment) {
            result.append(c) catch @panic("could not append to result in __extract_imports\n");
            i += 1;
            continue;
        }

        result.append(c) catch @panic("could not append to result in __extract_imports\n");
        i += 1;
    }

    return .{
        .code = result.toOwnedSlice() catch @panic("could not own result in __extract_imports\n"),
        .imports = imports,
    };
}

