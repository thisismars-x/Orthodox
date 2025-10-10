/////////////////////////////////////////////////////////////////////
////////////////////// NAME - RESOLUTION ///////////////////////////
////////////////////////////////////////////////////////////////////

const SymbolTable = @import("./SymbolTable.zig");
const create_symbol_table = SymbolTable.create_symbol_table;
const SYMBOL_TABLE = SymbolTable.SYMBOL_TABLE;

const Parser = @import("./Parser.zig").Parser;

const AST = @import("./AST.zig");
const TYPES = AST.TYPES;
const DEFINITIONS = AST.DEFINITIONS;
const LITERALS = AST.LITERALS;

const std = @import("std");
const print = std.debug.print;


pub fn is_type_mut(__type: TYPES) bool {

    return 
    switch(__type) {

        .number => __type.number.mut,
        .string => __type.string.mut,
        .char   => __type.char.mut,
        .pointer => __type.pointer.mut,
        .reference => __type.reference.mut,
        .array => __type.array.mut,
        .record => __type.record.mut,

        else => @panic("functions make no sense to is_type_mut\n"),

    };

}

pub fn does_enum_have_field(__enum_def: DEFINITIONS, __field: []const u8) bool {

    for(__enum_def.enum_def.fields.items) |field| {
        if(std.mem.eql(u8, field, __field)) return true;
    } 

    return false;

}

pub fn does_struct_have_field(__struct_def: DEFINITIONS, __field: []const u8) bool {

    var fields_types = __struct_def.struct_def.fields_types.iterator();
    while(fields_types.next()) |field| {
        if(std.mem.eql(u8, field.key_ptr.*, __field)) return true;
    }

    return false;

}

pub fn inspect_struct_field_type(__struct_def: DEFINITIONS, __field: []const u8) TYPES {

    if(does_struct_have_field(__struct_def, __field) == false) @panic("__struct_def has no field __field\n");
    return __struct_def.struct_def.fields_types.get(__field).?.*;

}


//////////////////////// VARIABLE + TYPE RESOLUTION ////////////////////////////////////////////// start ////

pub const NAME_SCOPE = union(enum) {
    GLOBAL,
    BLOCK: struct{ lvl: u32 },

    NOT_FOUND, // this variable / type is not in scope

};

// pub fn __variable_name_resolution(__name: []const u8, __sym_tbl: SYMBOL_TABLE, __n_block: u32) NAME_SCOPE {
//
// }

//
// in a decl like: a :: logger; checks if logger is in global scope
pub fn __type_name_resolution(__type: []const u8, __sym_tbl: SYMBOL_TABLE) NAME_SCOPE {

    for(__sym_tbl.items) |item| {

        switch(item) {

            .struct_mapping =>
            {
                if(std.mem.eql(u8, item.struct_mapping.struct_name, __type)) {
                    return NAME_SCOPE.GLOBAL;
                }
            },

            .enum_mapping =>
            {
                if(std.mem.eql(u8, item.enum_mapping.enum_name, __type)) {
                    return NAME_SCOPE.GLOBAL;
                }
            },

            else => { }

        }

    }

    return NAME_SCOPE.NOT_FOUND;

}

//////////////////////// VARIABLE + TYPE RESOLUTION ////////////////////////////////////////////// start ////



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////// NAME - RESOLUTION TESTS ///////////////////////////////////////// NAME - RESOLUTION TESTS ///////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

test {
    // const s = 
    // \\ main :: proc() void {
    // \\      a :: mut i32;
    // \\
    // \\          {
    // \\              a = 100;
    // \\          }
    // \\ };
    // ;

    var parser = Parser.raw_init_with_file("./file.ox");

    const parsed = parser.parse_program();
    const symbol_table = create_symbol_table(parsed);

    for(symbol_table.items) |sym_tbl| {
        
        switch(sym_tbl) {
            
            .function_mapping => print("fn-name :: {s}\n", .{sym_tbl.function_mapping.fn_name}),
            else => {}


        }

    }
}

test {
    print("-- TEST DOES_ENUM_HAVE_FIELD\n", .{});

    const s = 
    \\
    \\ WARN :: enum {
    \\      LEVEL0,
    \\      LEVEL1,
    \\ };
    ;

    var parser = Parser.init_for_tests(s);
    const enum_def = parser.parse_enum_def();

    print("{any}\n", .{does_enum_have_field(enum_def, "LEVEL1")});

    print("passed..\n\n", .{});
}

test {
    print("-- TEST DOES_STRUCT_HAVE_FIELD\n", .{});

    const s = 
    \\
    \\ logger :: struct {
    \\      warn :: WARN,
    \\      level :: u32,
    \\ };
    ;

    var parser = Parser.init_for_tests(s);
    const struct_def = parser.parse_struct_def();

    print("{any}\n", .{does_struct_have_field(struct_def, "level")});

    print("type :: {any}\n", .{inspect_struct_field_type(struct_def, "warn")});

    print("passed..\n\n", .{});
}

test {
    print("-- TEST __VARIABLE_NAME_RESOLUTION\n", .{});

    const s = 
    \\ 
    \\ number :: struct {lvl:: i32,};
    \\
    \\ add :: proc(a :: i32, b :: i32) i32 {
    \\
    \\      x :: i32 = a;
    \\      y :: i32 = b;
    \\      {
    \\          b :: i32 = x + y;
    \\      }
    \\ };
    ;

    var parser = Parser.init_for_tests(s);
    const program = parser.parse_program();
    const sym_tbl = create_symbol_table(program);

    // print("found b? {any}\n", .{__variable_name_resolution("x", "add", sym_tbl)});
    print("found struct number? {any}\n", .{__type_name_resolution("number", sym_tbl)});

    print("passed..\n\n", .{});
}
