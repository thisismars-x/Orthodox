/////////////////////////////////////////
///////// SCOPE - LEAKAGE //////////////
////////////////////////////////////////


const Parser = @import("./Parser.zig").Parser;
const AST = @import("./AST.zig");
const DEFINITIONS = AST.DEFINITIONS;
const STATEMENTS = AST.STATEMENTS;
const EXPRESSIONS = AST.EXPRESSIONS;
const LITERALS = AST.LITERALS;

pub usingnamespace DEFINITIONS;
pub usingnamespace STATEMENTS;
pub usingnamespace EXPRESSIONS;
pub usingnamespace LITERALS;

const std = @import("std");
const print = std.debug.print;

//
// default allocators throughout SCOPE_LEAKAGE 
var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
const default_allocator = gpa.allocator();


///////////////////////////////// @CORE - CHECK SCOPE LEAK /////////////////////////////////////////////////////// start //// 

pub fn check_scope_leak(block: STATEMENTS, __symbol_table: std.ArrayList([]const u8), fn_name: []const u8) void {

    var symbol_table = std.ArrayList([]const u8).init(default_allocator);
    for(__symbol_table.items) |item| {
        symbol_table.append(item) catch @panic("could not append to symbol_table\n");
    }


    switch(block) {

        // a block starts with a { .. } - block
        .block =>
        {

            const block_inner_elem = block.block.inner_elements;
            for(block_inner_elem.items) |block_elem| {

                switch(block_elem) {

                    .assignment => 
                    {
                        symbol_table.append(block_elem.assignment.lvalue_name) catch @panic("could not append to symbol_table\n");

                        if(block_elem.assignment.rvalue_expr) |rvalue_expr| {
                            check_expr_against_symbol_table(rvalue_expr.*, symbol_table, fn_name);
                        }

                    },

                    .update =>
                    {
                        check_expr_against_symbol_table(block_elem.update.rvalue_expr.*, symbol_table, fn_name);
                    },

                    // record the last elem in the symbol table before the block starts
                    // then when block ends pop all elements till that last elem
                    .block =>
                    {
                        const before_block_len = symbol_table.items.len;

                        // add block's symbols into the symbol table
                        check_scope_leak(block_elem, symbol_table, fn_name);

                        // when block exits, pop all the symbol of that block
                        while(symbol_table.items.len > before_block_len) _ = symbol_table.pop();

                    },

                    .for_stmt =>
                    {
                        
                        // for i in ...., 'i' should be accessible
                        symbol_table.append(block_elem.for_stmt.identifier_name) catch @panic("could not append to symbol_table\n");

                        check_expr_against_symbol_table(block_elem.for_stmt.range_expr1.*, symbol_table, fn_name);

                        check_expr_against_symbol_table(block_elem.for_stmt.range_expr2.*, symbol_table, fn_name);

                        check_scope_leak(block_elem.for_stmt.for_block.*, symbol_table, fn_name);

                        _ = symbol_table.pop(); // remove that identifier name 

                    },

                    .loop_stmt =>
                    {
                        check_scope_leak(block_elem.loop_stmt.loop_block.*, symbol_table, fn_name);
                    },

                    .conditional_stmt =>
                    {
                        check_expr_against_symbol_table(block_elem.conditional_stmt.if_cond.*, symbol_table, fn_name);
                        check_scope_leak(block_elem.conditional_stmt.if_block.*, symbol_table, fn_name);
                        
                        // since, elif conds are optional
                        if(block_elem.conditional_stmt.elif_conds) |_| {
                            const len = block_elem.conditional_stmt.elif_conds.?.items.len;

                            for(0..len) |idx| {
                                check_expr_against_symbol_table(block_elem.conditional_stmt.elif_conds.?.items[idx].*, symbol_table, fn_name);
                                check_scope_leak(block_elem.conditional_stmt.elif_blocks.?.items[idx].*, symbol_table, fn_name);
                            } 
                        }
                        
                        // else conds are optional
                        if(block_elem.conditional_stmt.else_block) |else_block| {
                            check_scope_leak(else_block.*, symbol_table, fn_name);
                        }

                    },

                    else => {}


                }


            }
            

        },

        else => {}

    }


}

///////////////////////////////// @CORE - CHECK SCOPE LEAK /////////////////////////////////////////////////////// end ////// 


//////////////////////////////////// EXPR - MATCHING  //////////////////////////////////////////////////////////// start ////

// 
// yes, if symbol table contains 'name', no, if 'name' is absent
pub const CONTAINS = union(enum) {
    YES,
    NO: []const u8, 
};


// 
// checks an entire expression for names, if they are within scope, or not
pub fn check_expr_against_symbol_table(expr: EXPRESSIONS, symbol_table: std.ArrayList([]const u8), fn_name: []const u8) void {
    const expr_names = expressions_name_collection(expr);
    const lookup = match_expression_names_with_symbol_table(expr_names, symbol_table);

    switch(lookup) {
        .NO =>
        {
            print("SCOPE_LEAK_ERROR :: use of undeclared identifier '{s}' in proc '{s}'\n\n", .{lookup.NO, fn_name});
            print("Process terminated with exit status 1\n\n", .{});
            std.process.exit(0);
        },

        else => {  }
    }

}


//
// does symbol_table contain all symbols in name_list
pub fn match_expression_names_with_symbol_table(name_list: std.ArrayList([]const u8), symbol_table: std.ArrayList([]const u8)) CONTAINS {
    const contain = CONTAINS.YES;

    for(name_list.items) |name| {
        if(!contains(symbol_table, name)) {
            return CONTAINS { .NO = name };
        }
    }

    return contain;

}

//
// finds LIST INTERSECTION NAME == NOT_NULL
pub fn contains(list: std.ArrayList([]const u8), name: []const u8) bool {
    for(list.items) |item| {
        if(std.mem.eql(u8, name, item)) return true;
    }

    return false;
}

//
// destructures an expression to collect all names contained in it
pub fn expressions_name_collection(expr: EXPRESSIONS) std.ArrayList([] const u8) {

    var names = std.ArrayList([]const u8).init(default_allocator);

    switch(expr) {

        .literal_expr =>
        {
            // literal can be variable or member access(in member access only note base record name)
            const literal_name = expr.literal_expr.inner_literal;

            switch(literal_name) {
                
                .variable =>
                {
                    const var_name = literal_name.variable.inner_value;
                    names.append(var_name) catch @panic("could not append to names\n");
                },

                .member_access =>
                {
                    const var_name = literal_name.member_access.record_type_name;
                    names.append(var_name) catch @panic("could not append to names\n");
                },

                .pointer_deref => 
                {
                    const top_literal = literal_name.pointer_deref.deref_literal.*;

                    // instead of looping, make this work only once, this way, pointer deref and array access
                    // can only happen in 1 level of indirection
                    switch(top_literal) {

                        .variable => 
                        {
                            const var_name = top_literal.variable.inner_value;
                            names.append(var_name) catch @panic("could not append to names\n");
                        },

                        .member_access =>
                        {
                            const var_name = top_literal.member_access.record_type_name;
                            names.append(var_name) catch @panic("could not append to names\n");
                        },

                        else => {  }

                    }

                },

                .array_access => 
                {
                    const top_literal = literal_name.array_access.array_var.*;

                    switch(top_literal) {

                        .variable => 
                        {
                            const var_name = top_literal.variable.inner_value;
                            names.append(var_name) catch @panic("could not append to names\n");
                        },

                        .member_access =>
                        {
                            const var_name = top_literal.member_access.record_type_name;
                            names.append(var_name) catch @panic("could not append to names\n");
                        },

                        else => {  }

                    }

                    const access_index = expressions_name_collection(literal_name.array_access.access_index.*); 

                    for(access_index.items) |name| {
                        names.append(name) catch @panic("could not append to names\n");
                    }

                },

                else =>
                {  } // nothing to do

            }

            const literal_inner_expr = expr.literal_expr.inner_expr;
            const literal_inner = expressions_name_collection(literal_inner_expr.*);

            for(literal_inner.items) |name| {
                names.append(name) catch @panic("could not append to names\n");
            }

        },

        .operator_expr =>
        {
            const inner_expr = expr.operator_expr.inner_expr;
            const op_names = expressions_name_collection(inner_expr.*);

            for(op_names.items) |name| {
                names.append(name) catch @panic("could not append to names\n");
            }

        },


        .fn_call_expr =>
        {
            for(expr.fn_call_expr.inner_expr_list.items) |inner_expr| {
                const inner_name = expressions_name_collection(inner_expr.*);

                for(inner_name.items) |name| {
                    names.append(name) catch @panic("could not append to names\n");
                }
            }

            // parse_fn_call_expr parses expr after fn_expr too, for eg.
            // 1 + 2 + x(y, z) - 4 + 3, -4 + 3 is part of fn_call_expr
            const then_name = expressions_name_collection(expr.fn_call_expr.then_expr.*);

            for(then_name.items) |name| {
                names.append(name) catch @panic("could not append to names\n");
            }

        },

        .return_expr =>
        {
            const return_expr = expressions_name_collection(expr.return_expr.inner_expr.*);
            for(return_expr.items) |name| {
                names.append(name) catch @panic("could not append to names\n");
            }
        },

        // for struct init
        .struct_expr =>
        {
            var field_values = expr.struct_expr.fields_values.iterator();
            while(field_values.next()) |get_value_only| {
                const inner_names = expressions_name_collection(get_value_only.value_ptr.*.*);
                for(inner_names.items) |name| {
                    names.append(name) catch @panic("could not append to names\n");
                }
            }
        },

        // for '( expr )'
        .closed_expr =>
        {
            const closed_expr = expressions_name_collection(expr.closed_expr.inner_expr.*);
            for(closed_expr.items) |name| {
                names.append(name) catch @panic("could not append to names\n");
            }
        },

        else => {}



    }

    return names;

}

//
// fn-args are in scope throughout the function
pub fn get_fn_arg_names(func: DEFINITIONS) ?std.ArrayList([]const u8) {

    var arg_names = std.ArrayList([]const u8).init(default_allocator);

    switch(func) {

        .function_def =>
        {
            const fn_type = func.function_def.fn_type.*;  
            const args_and_types = fn_type.function.args_and_types;

            if(args_and_types) |__args_and_types| {
                var args_iter = __args_and_types.iterator(); 

                while(args_iter.next()) |arg| {
                    arg_names.append(arg.key_ptr.*) catch @panic("could not append to arg_names in get_fn_arg_names\n");

                }


            } else return null;

        },

        else =>
        @panic("get_fn_arg_names expected DEFINITIONS{ .function_def = { .. }}\n"),

    }

    return arg_names;

}


//////////////////////////////////// EXPR - MATCHING  //////////////////////////////////////////////////////////// start ////


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////// SCOPE - LEAKAGE TESTS /////////////////////// SCOPE - LEAKAGE TESTS /////////////////////// SCOPE - LEAKAGE TESTS //////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//
// test {
//     print("-- TEST GET_NAMES_IN_EXPRESSION\n", .{});
//
//     var parser = Parser.init_for_tests("c + 1 - a >> EFGH - get_number(math.pi / six) + p.g + roundoff(2.0) - eighty + ninety;");
//     const expr = parser.parse_expr();
//     const names = expressions_name_collection(expr.*);
//
//     for(names.items) |name| {
//         print("{s}\t", .{name});
//     }
//
//     print("\n", .{});
//     print("passed..\n\n", .{});
//
// }
//
// test {
//     print("-- TEST GET_NAMES_IN_EXPRESSION\n", .{});
//
//     var parser = Parser.init_for_tests("logger { .warn = yes, .when = number + 5 - thirty.two, .x = y { .p = seventy, };, };");
//     const expr = parser.parse_expr();
//     const names = expressions_name_collection(expr.*);
//
//     for(names.items) |name| {
//         print("{s}\t", .{name});
//     }
//
//     print("\n", .{});
//     print("passed..\n\n", .{});
//
// }
//
// test {
//     print("-- TEST FN_ARG_NAMES\n", .{});
//
//     var parser = Parser.init_for_tests("add :: proc(a :: u32, b :: u32) u64 {};");
//     const fn_def = parser.parse_fn_def();
//     const names = get_fn_arg_names(fn_def);
//
//     for(names.?.items) |name| {
//         print("{s}\t", .{name});
//     }
//
//     print("\n", .{});
//     print("passed..\n\n", .{});
//
// }
//
// test {
//     print("-- CHECK SCOPE LEAK\n", .{});
//
//     const s = 
//     \\ anon :: proc() void {
//     \\       a :: mut i32;
//     \\       b :: i32 = a; 
//     \\
//     \\       for x in 100 + 200 : a + b : {
//     \\             l :: i32 = x;
//     \\       }
//     \\ 
//     \\      some_number :: i32 = 500;
//     \\
//     \\      if some_number == 40 : {
//     \\          lpd :: i32;
//     \\          mpd :: i32;
//     \\      } elif some_number == 200 : {
//     \\          lpd :: i64 = (a + b + (a - b + (a ** b)) + a + a[c]);
//     \\      }
//     \\       
//     \\ };
//     ;
//
//     var parser = Parser.init_for_tests(s);
//     const parsed = parser.parse_program();
//
//     const list = std.ArrayList([]const u8).init(default_allocator);
//     check_scope_leak(parsed.items[0].function_def.fn_block, list, "anon");
//
//     print("passed..\n\n", .{});
// }
