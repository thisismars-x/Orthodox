///////////////////////////////////////////////////////////////
//////////////////// SYMBOL-TABLE /////////////////////////////
///////////////////////////////////////////////////////////////

const AST = @import("./AST.zig");
const TYPES = AST.TYPES;

const PARSER = @import("./Parser.zig");

//
// single sym-table is constructed for each compilation
// a sym-table works like so ~
// goto each variable decl, then, note that variable's name, type, scope
// after sym-table is constructed, perform name resolution and type-checking
pub const SYMBOL_TABLE = struct {

    sym_stack: std.ArrayList(SYMBOL),

    // 
    // default allocator throughout the SYMBOL_TABLE, 
    // deallocated only when program exits
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    const default_allocator = gpa.allocator();


};

//
// every variable in a scope, gets a SYMBOL
// informing about its depth(scope), width(type), 
// height(level_which), and its name
pub const SYMBOL = struct {
    sym_scope: SCOPE,
    sym_type: TYPES,
    sym_name: []const u8,

    level_which: i32,

};

pub const SCOPE = enum {
    GLOBAL,
    LOCAL,
    FUNCTION,

};
