///////////////////////////////////////////////////////////////
////////////////////// SYMBOL-TABLE ///////////////////////////
///////////////////////////////////////////////////////////////

pub const AST = @import("./AST.zig");
pub const DEFINITIONS = AST.DEFINITIONS;
pub const EXPRESSIONS = AST.EXPRESSIONS;
pub const TYPES = AST.TYPES;
pub const STATEMENTS = AST.STATEMENTS;
pub const LITERALS = AST.LITERALS;

pub const Parser = @import("./Parser.zig").Parser;

pub const std = @import("std");
pub const print = std.debug.print;
pub const heap = std.heap;

pub usingnamespace STATEMENTS;

//
// default allocators throughout the SYMBOL_TABLE
var gpa: heap.GeneralPurposeAllocator(.{}) = .{};
const default_allocator = gpa.allocator();

//
// creates sym_stack from assignment statements in a block
// the only assignment statements in a block, concern variables,
// struct | enum | fn can not be defined inside blocks
// next_level refers to current_level + 1
pub fn create_sym_stack(block: STATEMENTS, next_level: u32) SYMBOL_STACK {
    var sym_stack: SYMBOL_STACK = std.ArrayList(VARIABLE_MAPPING).init(default_allocator);
    var current_block_level = next_level;

    switch(block) {

        .block =>
        {

            const block_inner_elements = block.block.inner_elements.items;

            for(block_inner_elements) |block_item| {

                switch(block_item) {

                    .assignment =>
                    {
                        const block_item_var_mapping = create_var_mapping_for_vars(block_item, SCOPE.BLOCK, current_block_level);
                        sym_stack.append(block_item_var_mapping) catch @panic("could not append to sym_stack in create_sym_stack\n");

                    },

                    .block =>
                    {
                        current_block_level += 1;

                        const inner_block = create_sym_stack(block_item, current_block_level);
                        for(inner_block.items) |inner_block_item| {
                            sym_stack.append(inner_block_item) catch @panic("could not append to sym_stack in create_sym_stack\n");
                        }

                        current_block_level -= 1;

                    },

                    .for_stmt => 
                    {
                        current_block_level += 1;

                        const inner_for_block = create_sym_stack(block_item.for_stmt.for_block.*, current_block_level);
                        for(inner_for_block.items) |inner_block_item| {
                            sym_stack.append(inner_block_item) catch @panic("could not append to sym_stack in create_sym_stack\n");
                        }

                        current_block_level -= 1;

                    },

                    .loop_stmt =>
                    {
                        current_block_level += 1;

                        const inner_loop_block = create_sym_stack(block_item.loop_stmt.loop_block.*, current_block_level);
                        for(inner_loop_block.items) |inner_block_item| {
                            sym_stack.append(inner_block_item) catch @panic("could not append to sym_stack in create_sym_stack\n");
                        }

                        current_block_level -= 1;

                    },

                    .conditional_stmt =>
                    {
                        current_block_level += 1;

                        // if-condition
                        const inner_if_block = create_sym_stack(block_item.conditional_stmt.if_block.*, current_block_level);
                        for(inner_if_block.items) |inner_block_item| {
                            sym_stack.append(inner_block_item) catch @panic("could not append to sym_stack in create_sym_stack\n");
                        }

                        // if elif-conditions are possible
                        if(block_item.conditional_stmt.elif_blocks) |elif_blocks| {
                            for(elif_blocks.items) |elif_block| {
                                const inner_elif_block = create_sym_stack(elif_block.*, current_block_level);
                                for(inner_elif_block.items) |inner_block_item| {
                                    sym_stack.append(inner_block_item) catch @panic("could not append to sym_stack in create_sym_stack\n");
                                }

                            }

                        }

                        // if else-condition is possible
                        if(block_item.conditional_stmt.else_block) |else_block| {
                            const inner_else_block = create_sym_stack(else_block.*, current_block_level);
                            for(inner_else_block.items) |inner_block_item| {
                                sym_stack.append(inner_block_item) catch @panic("could not append to sym_stack in create_sym_stack\n");
                            }

                        }

                        current_block_level -= 1;

                    },

                    else => {},

                }


            }


        },

        else =>
        @panic("desired STATEMENTS{.block = {..}} in create_sym_stack\n"),


    }


    return sym_stack;

}



////////////////////// CORE @SYMBOL_TABLE ////////////////////////////////////////////// start ///

//
// A program contains exactly one symbol table,
// with all struct | enum | fn def - mappings
pub const SYMBOL_TABLE = std.ArrayList(NAMED_MAPPINGS);

//
// maps everything that makes a program(std.ArrayList(DEFINITIONS) ~ DEFINITIONS = STRUCT, ENUM, FN DEF)
pub const NAMED_MAPPINGS = union(enum) {
    struct_mapping: STRUCT_MAPPING,
    enum_mapping: ENUM_MAPPING,
    function_mapping: FUNCTION_MAPPING,

};

//
// creates symbol table for entire program top-down
pub fn create_symbol_table(program: std.ArrayList(DEFINITIONS)) SYMBOL_TABLE {
    var sym_table: SYMBOL_TABLE = std.ArrayList(NAMED_MAPPINGS).init(default_allocator);


    for(program.items) |program_def| {

        var named_mapping: NAMED_MAPPINGS = undefined;
        
        switch(program_def) {

            .struct_def =>
            named_mapping = NAMED_MAPPINGS {
                .struct_mapping = create_struct_mapping_for_struct_defs(program_def),
            },

            .enum_def =>
            named_mapping = NAMED_MAPPINGS {
                .enum_mapping = create_enum_mapping_for_enum_defs(program_def),
            },


            .function_def =>
            named_mapping = NAMED_MAPPINGS {
                .function_mapping = create_fn_mapping_for_fn_defs(program_def),
            },

        }

        sym_table.append(named_mapping) catch @panic("could not append to sym_table\n");
    }

    return sym_table;

}

////////////////////// CORE @SYMBOL_TABLE ////////////////////////////////////////////// end /////




///////////////////////// RECORD - MAPPINGS /////////////////////////////////////////// start ///

// 
// SCOPE.GLOBAL struct definitions
pub const STRUCT_MAPPING = struct {
    struct_name: []const u8,
    fields_types: std.StringHashMap(*TYPES),

    const scope = SCOPE.GLOBAL;

};

//
// create a struct_mapping from struct_def, including field_types list
pub fn create_struct_mapping_for_struct_defs(assignment: DEFINITIONS) STRUCT_MAPPING {
    var struct_mapping: STRUCT_MAPPING = undefined;

    switch(assignment) {

        .struct_def =>
        {
            struct_mapping.struct_name = assignment.struct_def.struct_name;
            struct_mapping.fields_types = assignment.struct_def.fields_types;

        },

        else =>
        @panic("desired DEFINITIONS {.struct_def = .{ ... }}, in create_var_mapping_for_struct_defs\n"),
    }

    return struct_mapping;
}

//
// SCOPE.GLOBAL enum definitions
pub const ENUM_MAPPING = struct {
    enum_name: []const u8,
    fields: std.ArrayList([]const u8),

    const scope = SCOPE.GLOBAL;

};

//
// create a enum_mapping for enum_def, including enum_fields_list
pub fn create_enum_mapping_for_enum_defs(assignment: DEFINITIONS) ENUM_MAPPING {
    var enum_mapping: ENUM_MAPPING = undefined;

    switch(assignment) {

        .enum_def =>
        {
            enum_mapping.enum_name = assignment.enum_def.enum_name;
            enum_mapping.fields = assignment.enum_def.fields;

        },

        else =>
        @panic("desired DEFINITIONS {.enum_def = .{ ... }}, in create_var_mapping_for_enum_defs\n"),
    }

    return enum_mapping;
}

///////////////////////// RECORD - MAPPINGS /////////////////////////////////////////// end /////




///////////////////////// FUNCTION - MAPPINGS ///////////////////////////////////////// start ///

// 
// SCOPE.GLOBAL function definitions
pub const FUNCTION_MAPPING = struct {
    fn_name: []const u8,
    fn_type: TYPES,
    fn_sym_stack: SYMBOL_STACK,

    const scope = SCOPE.GLOBAL;
};

//
// creates function mapping
pub fn create_fn_mapping_for_fn_defs(assignment: DEFINITIONS) FUNCTION_MAPPING {
    var fn_mapping: FUNCTION_MAPPING = undefined;
    
    switch(assignment) {

        .function_def =>
        {
            fn_mapping.fn_name = assignment.function_def.fn_name;
            fn_mapping.fn_type = assignment.function_def.fn_type.*;
            fn_mapping.fn_sym_stack = create_sym_stack(assignment.function_def.fn_block, 0);

        },

        else =>
        @panic("desired DEFINITIONS {.function_def = .{ ... }}, in create_fn_mapping_for_fn_defs\n"),

    }



    return fn_mapping;
}

///////////////////////// FUNCTION - MAPPINGS ///////////////////////////////////////// end /////




///////////////////////// VARIABLE - MAPPINGS /////////////////////////////////////////// start ////

// 
// A single symbol_stack contains all variable_mappings of that scope
pub const SYMBOL_STACK = std.ArrayList(VARIABLE_MAPPING);

// 
// variable_mapping entails the relationship between 
// variables and their properties
pub const VARIABLE_MAPPING = struct {
    variable_name: []const u8,

    variable_scope: SCOPE,

    // block_scope level increases for each nested block
    variable_block_scope_level: u32, 

    variable_type: TYPES,

};

// 
// a global scope entails struct | enum | fn definitions
// a block scope entails STATEMENTS enclosed in '{' ..... '}'
pub const SCOPE = enum {
    GLOBAL,
    BLOCK,

};

//
// creates a var_mapping from symbols inside a block, given its scope and block_level(current_level)
pub fn create_var_mapping_for_vars(assignment: STATEMENTS, scope: SCOPE, block_level: u32) VARIABLE_MAPPING {
    var var_mapping: VARIABLE_MAPPING = undefined;

    var_mapping.variable_block_scope_level = block_level;
    var_mapping.variable_scope = scope;

    switch(assignment) {

        .assignment =>
        {
            var_mapping.variable_name = assignment.assignment.lvalue_name;
            var_mapping.variable_type = assignment.assignment.lvalue_type.*;

        },

        else =>
        @panic("desired STATEMENTS {.assignment = .{ ... }}, in create_var_mapping_for_vars\n"),
    }

    return var_mapping;
}

///////////////////////// VARIABLE - MAPPINGS /////////////////////////////////////////// end //////



///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////// SYMBOL_TABLE TESTS ///////////////////////////// SYMBOL_TABLE TESTS ///////////////////////////// SYMBOL_TABLE TESTS /////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

test {
    print("-- TEST CREATE_VAR_MAPPING_FOR_VARS\n", .{});

    var parser = Parser.init_for_tests("a :: mut i32 = 100;");
    const assignment = parser.parse_assign_stmt();

    const assign_var_mapping = create_var_mapping_for_vars(assignment, SCOPE.GLOBAL, 0);
    print("{any} :: \n", .{assign_var_mapping});

    print("passed..\n\n", .{});
}

test {
    print("-- TEST CREATE_VAR_MAPPING_FOR_STRUCT_DEF\n", .{});

    var parser = Parser.init_for_tests("logger :: struct { level :: i32, warn :: WARN, };");
    const assignment = parser.parse_struct_def();

    const assign_struct_mapping = create_struct_mapping_for_struct_defs(assignment);

    print("struct-name :: {s}\n", .{assign_struct_mapping.struct_name});

    var ft_iter =   assign_struct_mapping.fields_types.iterator();
    while(ft_iter.next()) |ft| {
        print("{s} :: {any}\n", .{ft.key_ptr.*, ft.value_ptr.*});
    }

    print("passed..\n\n", .{});
}


test {
    print("-- TEST CREATE_VAR_MAPPING_FOR_ENUM_DEF\n", .{});

    var parser = Parser.init_for_tests("logger_b :: enum { level0, level1, level2, };");
    const assignment = parser.parse_enum_def();

    const assign_enum_mapping = create_enum_mapping_for_enum_defs(assignment);

    print("enum-name :: {s}\n", .{assign_enum_mapping.enum_name});

    print("enum-field-list ::  ", .{});

    for(assign_enum_mapping.fields.items) |field| {
        print("{s}, ", .{field});
    }

    print("\n", .{});
    print("passed..\n\n", .{});
}

test {
    print("-- TEST CREATE_SYM_STACK\n", .{});

    const example_block = 
    \\ {
    \\      x :: mut i32 = 100;
    \\      x += 1;
    \\     
    \\      y :: String = "this is going to be a string";
    \\
    \\      z :: mut [1024]char;
    \\      print("print something", a, b, c);
    \\
    \\      {
    \\          p :: i32 = 4; 
    \\          z :: char = 'p';
    \\         
    \\
    \\          for i in a : b : {
    \\              number :: f64 = 213e+100;
    \\              
    \\              for j in c : d : { another_number :: mut i32; }
    \\              { more_numbers :: f128; }
    \\          }
    \\
    \\     }
    \\
    \\     loop : { 
    \\          keep_init_this_char :: char = 's';
    \\     }
    \\
    \\    if some_impossible_condition : {
    \\          some_thing :: i32;
    \\
    \\          if this_condition_may_occur >> 32 + 2 / 0 : {
    \\              other_thing :: mut i64;
    \\          }
    \\    } elif x + y + z : {
    \\          elif_number :: i32;
    \\    } else : {
    \\          else_number :: i32;
    \\          loop : { loop_number :: i32; }
    \\    }
    \\ }
    \\ 
    \\ 
    ;

    var parser = Parser.init_for_tests(example_block);
    const assignment = parser.parse_block();

    const assign_var_mapping = create_sym_stack(assignment, 0);

    for(assign_var_mapping.items) |block_item| {
        print("var_name  :: {s}\n", .{block_item.variable_name});
        print("var_scope :: {any}\n", .{block_item.variable_scope});
        print("var_scope :: {any}\n", .{block_item.variable_block_scope_level});
        print("var_type  :: {any}\n\n", .{block_item.variable_type});
    }

    print("passed..\n\n", .{});
}

test {
    print("-- TEST CREATE_SYM_TABLE_FOR_FUNCTION_DEFS\n", .{});

    const fn_def = 
    \\ main :: proc(argc :: u32, args :: String) void 
    \\ {
    \\      x :: mut i32 = 100;
    \\      x += 1;
    \\     
    \\      y :: String = "this is going to be a string";
    \\
    \\      z :: mut [1024]char;
    \\      print("print something", a, b, c);
    \\
    \\      {
    \\          p :: i32 = 4; 
    \\          z :: char = 'p';
    \\         
    \\
    \\          for i in a : b : {
    \\              number :: f64 = 213e+100;
    \\              
    \\              for j in c : d : { another_number :: mut i32; }
    \\              { more_numbers :: f128; }
    \\          }
    \\
    \\     }
    \\
    \\ };
    ;

    var parser = Parser.init_for_tests(fn_def);
    const parsed = parser.parse_fn_def();

    const fn_mapping = create_fn_mapping_for_fn_defs(parsed);
    print("fn_name :: {s}\n", .{fn_mapping.fn_name});

    const fn_type = fn_mapping.fn_type.function;
    var fn_args_types = fn_type.args_and_types.?.iterator();

    while(fn_args_types.next()) |kv| {
        print("{s} :: {any}\n", .{kv.key_ptr.*, kv.value_ptr.*});
    }

    print("return-type :: {any}\n", .{fn_type.return_type});

    const assign_var_mapping = fn_mapping.fn_sym_stack;

    for(assign_var_mapping.items) |block_item| {
        print("var_name  :: {s}\n", .{block_item.variable_name});
        print("var_scope :: {any}\n", .{block_item.variable_scope});
        print("var_scope :: {any}\n", .{block_item.variable_block_scope_level});
        print("var_type  :: {any}\n\n", .{block_item.variable_type});
    }

    print("passed..\n\n", .{});
}

test {
    print("-- TEST CREATE_SYMBOL_TABLE\n", .{});

    var parser = Parser.raw_init_with_file("./file.ox");
    const program = parser.parse_program();

    const sym_table = create_symbol_table(program);

    for(sym_table.items) |entry| {

        switch(entry) {

            .struct_mapping =>
            {
                const assign_struct_mapping = entry.struct_mapping;

                print("struct-name :: {s}\n", .{assign_struct_mapping.struct_name});

                var ft_iter =   assign_struct_mapping.fields_types.iterator();
                while(ft_iter.next()) |ft| {
                    print("{s} :: {any}\n", .{ft.key_ptr.*, ft.value_ptr.*});
                }

                print("\n", .{});
            },

            .enum_mapping =>
            {
                const assign_enum_mapping = entry.enum_mapping;

                print("enum-name :: {s}\n", .{assign_enum_mapping.enum_name});

                print("enum-field-list ::  ", .{});

                for(assign_enum_mapping.fields.items) |field| {
                    print("{s}, ", .{field});
                }

                print("\n\n", .{});
            },

            .function_mapping =>
            {
                const fn_mapping = entry.function_mapping;
                print("fn_name :: {s}\n", .{fn_mapping.fn_name});

                const fn_type = fn_mapping.fn_type.function;
                var fn_args_types = fn_type.args_and_types.?.iterator();

                while(fn_args_types.next()) |kv| {
                    print("{s} :: {any}\n", .{kv.key_ptr.*, kv.value_ptr.*});
                }

                print("return-type :: {any}\n", .{fn_type.return_type});

                const assign_var_mapping = fn_mapping.fn_sym_stack;

                for(assign_var_mapping.items) |block_item| {
                    print("var_name  :: {s}\n", .{block_item.variable_name});
                    print("var_scope :: {any}\n", .{block_item.variable_scope});
                    print("var_scope :: {any}\n", .{block_item.variable_block_scope_level});
                    print("var_type  :: {any}\n\n", .{block_item.variable_type});
                }

            },

        }
        

    }

    print("\n", .{});
    print("passed..\n\n", .{});
}
