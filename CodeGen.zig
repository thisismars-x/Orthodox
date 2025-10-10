////////////////////////////////////
////////// CODE GEN ////////////////
////////////////////////////////////

const AST = @import("./AST.zig");
const DEFINITIONS = AST.DEFINITIONS;
const STATEMENTS = AST.STATEMENTS;
const EXPRESSIONS = AST.EXPRESSIONS;
const LITERALS = AST.LITERALS;
const TYPES = AST.TYPES;
const OPERATORS = AST.OPERATORS;
const UPDATE_OPERATORS = AST.UPDATE_OPERATORS;

pub usingnamespace DEFINITIONS;
pub usingnamespace STATEMENTS;
pub usingnamespace OPERATORS;

const Parser = @import("./Parser.zig").Parser;

const std = @import("std");
const print = std.debug.print;
const exit = std.process.exit;

pub const BUFFER = []const u8;
pub const PROGRAM = std.ArrayList(DEFINITIONS);

//
// default allocators throughout code-gen
var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
const default_allocator = gpa.allocator();


const InformedEmission = @import("./InformedEmission.zig");
pub const EMIT = InformedEmission.Emit;


//////////////////////// CODE-GEN CORE - TRANSFORM PROGRAM ///////// start ////

pub fn __emit_program(program: PROGRAM, emitter: EMIT) void {

    const emit_to = emitter.filename.?;

    // open file, truncate if already existing
    var emit_file = std.fs.cwd().createFile(emit_to, .{}) catch @panic("could not open file for writing, check permissions\n");

    // this string gets written to the file at last
    var emitted_code = std.ArrayList(u8).init(default_allocator);

    // append default_directives atop
    if(emitter.permit_default_directives) {
        emitted_code.appendSlice(" // -+-+-+-+-+-+-+-+-+ DEFAULT-HEADERS +-+-+-+-+-+-+-+-+- //\n") catch @panic("could not append to emitted_code in __emit_program\n");
        emitted_code.appendSlice(emitter.emit_default_headers()) catch @panic("could not append to emitted_code in __emit_program\n");
        emitted_code.appendSlice("using namespace std;\n") catch @panic("could not append to emitted_code in __emit_program\n");
        emitted_code.appendSlice(" // -+-+-+-+-+-+-+-+-+ DEFAULT-HEADERS +-+-+-+-+-+-+-+-+- //\n") catch @panic("could not append to emitted_code in __emit_program\n");
    }

    emitted_code.appendSlice("\n\n") catch @panic("could not append to emitted_code in __emit_program\n");

    // hoist, struct | enum | fn def
    emitted_code.appendSlice("// -+-+-+-+-+-+-+-+-+-+ HOISTED DECLARATIONS +-+-+-+-+-+-+-+-+-+-+-//\n") catch @panic("could not append to emitted_code in __emit_program\n");
    emitted_code.appendSlice(__c_hoist_declarations(program)) catch @panic("could not append to emitted_code in __emit_program\n");
    emitted_code.appendSlice("// -+-+-+-+-+-+-+-+-+-+ HOISTED DECLARATIONS +-+-+-+-+-+-+-+-+-+-+-//\n") catch @panic("could not append to emitted_code in __emit_program\n");

    emitted_code.appendSlice("\n\n") catch @panic("could not append to emitted_code in __emit_program\n");

    // emit program after hoisting
    emitted_code.appendSlice(__c_emit_program(program)) catch @panic("could not append to emitted_code in __emit_program\n");

    emit_file.writeAll(emitted_code.toOwnedSlice() catch @panic("could not own slice owned by emitted_code\n")) catch @panic("could not write bytes to file in __emit_program\n");

    return;

}


pub fn __c_emit_program(program: PROGRAM) BUFFER {
    
    var __build_program = std.ArrayList(u8).init(default_allocator);

    for(program.items) |program_def| {
        const __c_emit_def = 
        switch(program_def) {
            .struct_def => __c_struct_def_transform(program_def, !HOIST),
            .enum_def => __c_enum_def_transform(program_def, !HOIST),
            .function_def => __c_fn_def_transform(program_def, !HOIST),

        };

        __build_program.appendSlice(__c_emit_def) catch @panic("could not append to __build_program in __c_emit_program\n");
        __build_program.append('\n') catch @panic("could not append to __build_program in __c_emit_program\n");

    }

    return __build_program.toOwnedSlice() catch @panic("could not own slice pointed by __build_program\n");

}


//////////////////////// CODE-GEN CORE - TRANSFORM PROGRAM ///////// start ////



////////////////////// CODE-GEN - HOISTING //////////////////////// start ////

// 
// To hoist function, struct and enum def i create a prototype of every definition
// right after header-include
pub fn __c_hoist_declarations(program: PROGRAM) BUFFER {
    var return_buffer = std.ArrayList(u8).init(default_allocator);

    for(program.items) |some_def| {
        switch(some_def) {
            .struct_def => return_buffer.appendSlice(__c_struct_def_transform(some_def, HOIST)) catch @panic("could not append to return_buffer in __c_hoist_declarations\n"),
            .enum_def => return_buffer.appendSlice(__c_enum_def_transform(some_def, HOIST)) catch @panic("could not append to return_buffer in __c_hoist_declarations\n"),
            .function_def => return_buffer.appendSlice(__c_fn_def_transform(some_def, HOIST)) catch @panic("could not append to return_buffer in __c_hoist_declarations\n"),
        }
    }


    return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by return_buffer\n");

}


////////////////////// CODE-GEN - HOISTING //////////////////////// start ////



/////////////////////// CODE-GEN EXPRESSIONS ////////////////////// start ////

// 
// approximately 32 literals can appear in a expr
const MAX_SIZE_OF_EXPR = MAX_PRINTED_SIZE_OF_LITERAL >> 32;

//
// return C_equivalent BUFFER for literal_expr 
pub fn __c_literal_expr_transform(expr: EXPRESSIONS) BUFFER {

    const literal = __c_literal_transform(expr.literal_expr.inner_literal);
    const rest_expr = __c_expr_transform(expr.literal_expr.inner_expr.*);

    var return_buffer = std.ArrayList(u8).init(default_allocator);
    return_buffer.appendSlice(literal) catch @panic("could not append to return_buffer in __c_literal_expr_transform\n");
    return_buffer.appendSlice(rest_expr) catch @panic("could not append to return_buffer in __c_literal_expr_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not toOwnedSlice return_buffer\n");

}

// 
// return C_equivalent BUFFER for operator_expr
pub fn __c_operator_expr_transform(expr: EXPRESSIONS) BUFFER {

    const op = __c_operator_transform(expr.operator_expr.inner_operator);
    const rest_expr = __c_expr_transform(expr.operator_expr.inner_expr.*);

    var return_buffer = std.ArrayList(u8).init(default_allocator);
    return_buffer.appendSlice(op) catch @panic("could not append to return_buffer in __c_literal_expr_transform\n");
    return_buffer.appendSlice(rest_expr) catch @panic("could not append to return_buffer in __c_literal_expr_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not toOwnedSlice return_buffer\n");

}

// 
// return C_equivalent BUFFER to fn_call_expr
pub fn __c_fn_call_expr_transform(expr: EXPRESSIONS) BUFFER {

    var return_buffer = std.ArrayList(u8).init(default_allocator);

    const fn_name = expr.fn_call_expr.fn_name;
    return_buffer.appendSlice(fn_name) catch @panic("could not append to return_buffer in __c_fn_call_expr_transform\n");

    // left_paren of fn_Call
    return_buffer.appendSlice(" ( ") catch @panic("could not append to return_buffer in __c_fn_call_expr_transform\n");

    const inner_expr_list = expr.fn_call_expr.inner_expr_list.items;
    for(inner_expr_list) |some_expr| {
        return_buffer.appendSlice(__c_expr_transform(some_expr.*)) catch @panic("could not append to return_buffer in __c_fn_call_expr_transform\n");
        return_buffer.appendSlice(", ") catch @panic("could not append to return_buffer in __c_fn_call_expr_transform\n");
    }

    // trailing comma
    if(inner_expr_list.len != 0) {
        _ = return_buffer.pop();
        _ = return_buffer.pop();
    }

    // close left paren of fn_Call
    return_buffer.appendSlice(" ) ") catch @panic("could not append to return_buffer in __c_fn_call_expr_transform\n");


    const then_expr = expr.fn_call_expr.then_expr;
    return_buffer.appendSlice(__c_expr_transform(then_expr.*)) catch @panic("could not append to return_buffer in __c_fn_call_expr_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not toOwnedSlice return_buffer\n");

}

//
// return C_equivalent for return_expr
pub fn __c_return_expr_transform(expr: EXPRESSIONS) BUFFER {

    var return_buffer = std.ArrayList(u8).init(default_allocator);
    return_buffer.appendSlice("return  ") catch @panic("could not append to return_buffer in __c_return_expr_transform\n");
    return_buffer.appendSlice(__c_expr_transform(expr.return_expr.inner_expr.*)) catch @panic("could not append to return_buffer in __c_return_expr_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not toOwnedSlice return_buffer\n");

}

//
// return C_equivalent of '( EXPR )'
pub fn __c_closed_expr_transform(expr: EXPRESSIONS) BUFFER {

    var return_buffer = std.ArrayList(u8).init(default_allocator);
    
    // '(' of the '( EXPR )' part
    return_buffer.appendSlice(" ( ") catch @panic("could not append to return_buffer in __c_closed_expr_transform\n");

    return_buffer.appendSlice(__c_expr_transform(expr.closed_expr.inner_expr.*)) catch @panic("could not append to return_buffer in __c_closed_expr_transform\n");

    // close the paren part
    return_buffer.appendSlice(" ) ") catch @panic("could not append to return_buffer in __c_closed_expr_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not toOwnedSlice return_buffer\n");

}

//
// return C_equivalent of struct init 
pub fn __c_struct_expr_transform(expr: EXPRESSIONS) BUFFER {
    var return_buffer = std.ArrayList(u8).init(default_allocator);

    const struct_expr = expr.struct_expr;
    const struct_name = struct_expr.struct_name;
    const init_fields_values = struct_expr.fields_values;

    return_buffer.appendSlice(struct_name) catch @panic("could not append to return_buffer in __c_struct_expr_transform\n");
    return_buffer.appendSlice(" { ") catch @panic("could not append to return_buffer in __c_struct_expr_transform\n");

    var field_values_iter = init_fields_values.iterator();
    while(field_values_iter.next()) |fv| {
        return_buffer.append('.') catch @panic("could not append to return_buffer in __c_struct_expr_transform\n");
        return_buffer.appendSlice(fv.key_ptr.*) catch @panic("could not append to return_buffer in __c_struct_expr_transform\n");
        return_buffer.append('=') catch @panic("could not append to return_buffer in __c_struct_expr_transform\n");
        return_buffer.appendSlice(__c_expr_transform(fv.value_ptr.*.*)) catch @panic("could not append to return_buffer in __c_struct_expr_transform\n");
        return_buffer.appendSlice(",\n") catch @panic("could not append to return_buffer in __c_struct_expr_transform\n");
    }

    return_buffer.appendSlice(" }; ") catch @panic("could not append to return_buffer in __c_struct_expr_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not toOwnedSlice return_buffer\n");

}

//
// NULL expressions are like pad-instructions
pub fn __c_NULL_expr_transform(_: EXPRESSIONS) BUFFER {
    var return_buffer = std.ArrayList(u8).init(default_allocator);
    
    return_buffer.appendSlice("") catch @panic("could not append to return_buffer in __c_NULL_expr_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not toOwnedSlice return_buffer\n");

}

//
// return C_equivalent for all types of expr
pub fn __c_expr_transform(expr: EXPRESSIONS) BUFFER {

    var return_buffer = std.ArrayList(u8).init(default_allocator);

    switch(expr) {

        .literal_expr => 
        return_buffer.appendSlice(__c_literal_expr_transform(expr)) catch @panic("could not appendSlice to return_buffer in __c_expr_transform\n"),

        .operator_expr =>
        return_buffer.appendSlice(__c_operator_expr_transform(expr)) catch @panic("could not appendSlice to return_buffer in __c_expr_transform\n"),

        .fn_call_expr =>
        return_buffer.appendSlice(__c_fn_call_expr_transform(expr)) catch @panic("could not appendSlice to return_buffer in __c_expr_transform\n"),

        .return_expr => 
        return_buffer.appendSlice(__c_return_expr_transform(expr)) catch @panic("could not appendSlice to return_buffer in __c_expr_transform\n"),

        .closed_expr =>
        return_buffer.appendSlice(__c_closed_expr_transform(expr)) catch @panic("could not appendSlice to return_buffer in __c_expr_transform\n"),

        .struct_expr =>
        return_buffer.appendSlice(__c_struct_expr_transform(expr)) catch @panic("could not appendSlice to return_buffer in __c_expr_transform\n"),

        .NULL =>
        return_buffer.appendSlice(__c_NULL_expr_transform(expr)) catch @panic("could not appendSlice to return_buffer in __c_expr_transform\n"),

    }


    return return_buffer.toOwnedSlice() catch @panic("could not toOwnedSlice return_buffer\n");

}


/////////////////////// CODE-GEN EXPRESSIONS ////////////////////// end //////


/////////////////////// CODE-GEN OPERATORS ///////////////////////// start ///

//
// simple, one to one mapping of operators 
pub fn __c_operator_transform(op: OPERATORS) BUFFER {

    const transformed_op = 
    switch(op) {
        
        OPERATORS.ADD => " + ",
        OPERATORS.MINUS => " - ",
        OPERATORS.MULTIPLY => " * ", 
        OPERATORS.DIVIDE => " / ",
        OPERATORS.MOD => " % ",
        OPERATORS.EXP => "DONT-KNOW-WHAT-TO-DO-WITH-EXP",
        OPERATORS.LEFT_SHIFT => " >> ",
        OPERATORS.RIGHT_SHIFT => " << ",
        OPERATORS.BITWISE_AND => " & ",
        OPERATORS.BITWISE_OR => " | ",
        OPERATORS.AND => " && ",
        OPERATORS.OR => " || ",

        OPERATORS.LT => " < ",
        OPERATORS.GT => " > ",
        OPERATORS.LE => " <= ",
        OPERATORS.GE => " >= ",

        OPERATORS.EQUAL => " == ",
        OPERATORS.NON_EQUAL => " != ",


    };

    const result = default_allocator.alloc(u8, transformed_op.len) catch @panic("allocation failed");
    std.mem.copyForwards(u8, result, transformed_op);

    return result;
}

//
// simple one-to-one mapping of update operators
pub fn __c_update_operator_transform(op: UPDATE_OPERATORS) BUFFER {

    const transformed_op = 
    switch(op) {
        .ASSIGN => " = ",
        .ADD_EQ => " += ",
        .MINUS_EQ => " -= ",
        .MUL_EQ => " *= ",
        .DIV_EQ => " /= ",
        .MOD_EQ => " %= ",
        .EXP_EQ => " DONT-KNOW-WHAT-TO-DO-WITH-EXP ",
        .LEFT_SHIFT_EQ => " >>= ",
        .RIGHT_SHIFT_EQ => " <<= ",
        .BITWISE_AND_EQ => " &= ",
        .BITWISE_OR_EQ => " |= ",

    };

    const result = default_allocator.alloc(u8, transformed_op.len) catch @panic("allocation failed");
    std.mem.copyForwards(u8, result, transformed_op);

    return result;

}

/////////////////////// CODE-GEN OPERATORS ///////////////////////// end /////


/////////////////////// CODE-GEN LITERALS //////////////////////// start ////

const MAX_PRINTED_SIZE_OF_LITERAL = 512;

//
// return C_equivalent BUFFER for literal
pub fn __c_literal_transform(literal: LITERALS) BUFFER {

    var buffer: [MAX_PRINTED_SIZE_OF_LITERAL]u8 = undefined;

    const transformed_literal: []const u8 = 
    switch(literal) {

        .number =>
        std.fmt.bufPrint(&buffer, " {s} ", .{literal.number.inner_value}) catch @panic("could not format string, maybe increase buffer buffer size\n"),
        
        .string =>
        std.fmt.bufPrint(&buffer, " {s} ", .{literal.string.inner_value}) catch @panic("could not format string, maybe increase buffer buffer size\n"),

        .char => 
        std.fmt.bufPrint(&buffer, " {s} ", .{literal.char.inner_value}) catch @panic("could not format string, maybe increase buffer buffer size\n"),

        .variable =>
        std.fmt.bufPrint(&buffer, " {s} ", .{literal.variable.inner_value}) catch @panic("could not format string, maybe increase buffer buffer size\n"),

        .member_access =>
        std.fmt.bufPrint(&buffer, " {s} ", .{structure_member_access(literal)}) catch @panic("could not format string, maybe increase buffer buffer size\n"),

        .pointer_deref =>
        ptr_blk: {
            const ptr_literal = __c_literal_transform(literal.pointer_deref.deref_literal.*);
            break :ptr_blk std.fmt.bufPrint(&buffer, " *{s} ", .{ptr_literal}) catch @panic("could not format string, maybe increase buffer buffer size\n");
        },

        .variable_ref =>
        ref_blk: {
            const ref_literal = __c_literal_transform(literal.variable_ref.ref_literal.*);
            break :ref_blk std.fmt.bufPrint(&buffer, " &{s} ", .{ref_literal}) catch @panic("could not format string, maybe increase buffer buffer size\n");
        },

        .array_access =>
        array_blk: {
            var return_buffer = std.ArrayList(u8).init(default_allocator);

            const array_name = __c_literal_transform(literal.array_access.array_var.*);
            const access_index = __c_expr_transform(literal.array_access.access_index.*);

            return_buffer.appendSlice(array_name) catch @panic("could not appendSlice to return_buffer in __c_literal_transform\n");
            return_buffer.appendSlice("[ ") catch @panic("could not appendSlice to return_buffer in __c_literal_transform\n");
            return_buffer.appendSlice(access_index) catch @panic("could not appendSlice to return_buffer in __c_literal_transform\n");
            return_buffer.appendSlice(" ]") catch @panic("could not appendSlice to return_buffer in __c_literal_transform\n");

            break :array_blk return_buffer.toOwnedSlice() catch @panic("could not toOwnedSlice return_buffer\n");
        },


    };


    // while returing buffer lifetimes do not live long enough, hence
    const result = default_allocator.alloc(u8, transformed_literal.len) catch @panic("allocation failed");
    std.mem.copyForwards(u8, result, transformed_literal);

    return result;

}

// 
// enum and struct member access is structured again
pub fn structure_member_access(literal: LITERALS) BUFFER {

    const record_type_name = literal.member_access.record_type_name;
    const members_name_in_order = literal.member_access.members_name_in_order;

    var buffer = std.ArrayList(u8).init(default_allocator);
    buffer.appendSlice(record_type_name) catch @panic("could not appendSlice to buffer in structure_member_access\n");

    for(members_name_in_order.items) |name| { 
        buffer.append('.') catch @panic("could not appendSlice to buffer in structure_member_access\n");
        buffer.appendSlice(name) catch @panic("could not appendSlice to buffer in structure_member_access\n");
    }

    return buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");
}

// 
// __o(ORTHODOX) to __cTYPE
pub fn map_internal_types(__o_type: BUFFER) BUFFER {

    // integer types
    if (std.mem.eql(u8, __o_type, "i8")) return "int8_t";
    if (std.mem.eql(u8, __o_type, "i16")) return "int16_t";
    if (std.mem.eql(u8, __o_type, "i32")) return "int32_t";
    if (std.mem.eql(u8, __o_type, "i64")) return "int64_t";
    if (std.mem.eql(u8, __o_type, "isize")) return "intptr_t";

    // unsigned integer types
    if (std.mem.eql(u8, __o_type, "u8")) return "uint8_t";
    if (std.mem.eql(u8, __o_type, "u16")) return "uint16_t";
    if (std.mem.eql(u8, __o_type, "u32")) return "uint32_t";
    if (std.mem.eql(u8, __o_type, "u64")) return "uint64_t";
    if (std.mem.eql(u8, __o_type, "usize")) return "uintptr_t";

    // floating point types
    if (std.mem.eql(u8, __o_type, "f32")) return "float";
    if (std.mem.eql(u8, __o_type, "f64")) return "double";
    if (std.mem.eql(u8, __o_type, "f128")) return "long double";

    // string
    if (std.mem.eql(u8, __o_type, "String")) return "string";
    if (std.mem.eql(u8, __o_type, "char")) return "char";

    // void type
    if (std.mem.eql(u8, __o_type, "void")) return "void";

    // no mapping found
    return __o_type; 
}


/////////////////////// CODE-GEN LITERALS //////////////////////// end //////


/////////////////////// CODE-GEN STATEMENTS ///////////////////// start ////

//
// for a in b : c : { .. } takes form for(int a = b; i < c; i++) <- note that a will always take int form
pub fn __c_for_stmt_transform(stmt: STATEMENTS) BUFFER {
    var return_buffer = std.ArrayList(u8).init(default_allocator);

    // for-header
    const for_stmt = stmt.for_stmt;

    return_buffer.appendSlice("for(int ") catch @panic("could not append to return_buffer in __c_for_stmt_transform\n");
    return_buffer.appendSlice(for_stmt.identifier_name) catch @panic("could not append to return_buffer in __c_for_stmt_transform\n");
    return_buffer.append('=') catch @panic("could not append to return_buffer in __c_for_stmt_transform\n");
    return_buffer.appendSlice(__c_expr_transform(for_stmt.range_expr1.*)) catch @panic("could not append to return_buffer in __c_for_stmt_transform\n");
    return_buffer.appendSlice("; ") catch @panic("could not append to return_buffer in __c_for_stmt_transform\n");

    return_buffer.appendSlice(for_stmt.identifier_name) catch @panic("could not append to return_buffer in __c_for_stmt_transform\n");
    return_buffer.append('<') catch @panic("could not append to return_buffer in __c_for_stmt_transform\n");
    return_buffer.appendSlice(__c_expr_transform(for_stmt.range_expr2.*)) catch @panic("could not append to return_buffer in __c_for_stmt_transform\n");
    return_buffer.appendSlice("; ") catch @panic("could not append to return_buffer in __c_for_stmt_transform\n");

    return_buffer.appendSlice(for_stmt.identifier_name) catch @panic("could not append to return_buffer in __c_for_stmt_transform\n");
    return_buffer.appendSlice("++ )") catch @panic("could not append to return_buffer in __c_for_stmt_transform\n");


    // for-block
    return_buffer.appendSlice(__c_block_stmt_transform(for_stmt.for_block.*)) catch @panic("could not append to return_buffer in __c_for_stmt_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");

}

//
// loop : { .. } takes form for(;;;)
pub fn __c_loop_stmt_transform(stmt: STATEMENTS) BUFFER {
    var return_buffer = std.ArrayList(u8).init(default_allocator);

    // loop header
    return_buffer.appendSlice("for(;;)") catch @panic("could not append to return_buffer in __c_loop_stmt_transform\n");

    // loop-block
    return_buffer.appendSlice(__c_block_stmt_transform(stmt.loop_stmt.loop_block.*)) catch @panic("could not append to return_buffer in __c_loop_stmt_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");

}

// 
// if/else if/else clause in C_equivalent
pub fn __c_conditional_stmt_transform(stmt: STATEMENTS) BUFFER {
    var return_buffer = std.ArrayList(u8).init(default_allocator);

    const cond_stmt = stmt.conditional_stmt;

    // if-header
    return_buffer.appendSlice("if( ") catch @panic("could not append to return_buffer in __c_conditional_stmt_transform\n"); 
    return_buffer.appendSlice(__c_expr_transform(cond_stmt.if_cond.*)) catch @panic("could not append to return_buffer in __c_conditional_stmt_transform\n"); 
    return_buffer.appendSlice(" )") catch @panic("could not append to return_buffer in __c_conditional_stmt_transform\n"); 

    // if-block
    return_buffer.appendSlice(__c_block_stmt_transform(cond_stmt.if_block.*)) catch @panic("could not append to return_buffer in __c_conditional_stmt_transform\n");

    return_buffer.append('\n') catch @panic("could not append to return_buffer in __c_conditional_stmt_transform\n"); 
    if(cond_stmt.elif_conds) |elif_conds| {
        for(elif_conds.items, cond_stmt.elif_blocks.?.items) |elif, block| {

            // elseif-header
            return_buffer.appendSlice("else if( ") catch @panic("could not append to return_buffer in __c_conditional_stmt_transform\n"); 
            return_buffer.appendSlice(__c_expr_transform(elif.*)) catch @panic("could not append to return_buffer in __c_conditional_stmt_transform\n"); 
            return_buffer.appendSlice(" )") catch @panic("could not append to return_buffer in __c_conditional_stmt_transform\n"); 
            return_buffer.append('\n') catch @panic("could not append to return_buffer in __c_conditional_stmt_transform\n"); 

            //elseif-block
            return_buffer.appendSlice(__c_block_stmt_transform(block.*)) catch @panic("could not append to return_buffer in __c_conditional_stmt_transform\n");
        }
    }

    if(cond_stmt.else_block) |else_blk| {
        
        // else-header 
        return_buffer.appendSlice("else if( ") catch @panic("could not append to return_buffer in __c_conditional_stmt_transform\n"); 

        //else-block
        return_buffer.appendSlice(__c_block_stmt_transform(else_blk.*)) catch @panic("could not append to return_buffer in __c_conditional_stmt_transform\n"); 

    }
    


    return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");

}

//
// C_equivalent of assignment
pub fn __c_assign_stmt_transform(stmt: STATEMENTS) BUFFER { 
    var return_buffer = std.ArrayList(u8).init(default_allocator);

    const lvalue_type = __c_types_transform(stmt.assignment.lvalue_type.*, !IS_STRUCT_DEF);
    const lvalue_name = stmt.assignment.lvalue_name;

    return_buffer.appendSlice(lvalue_type) catch @panic("could not append to return_buffer in __c_assign_stmt_transform\n"); 
    return_buffer.appendSlice(" ") catch @panic("could not append to return_buffer in __c_assign_stmt_transform\n"); 
    return_buffer.appendSlice(lvalue_name) catch @panic("could not append to return_buffer in __c_assign_stmt_transform\n"); 

    if(stmt.assignment.rvalue_expr) |rval| {
        return_buffer.appendSlice(" = ") catch @panic("could not append to return_buffer in __c_assign_stmt_transform\n"); 
        return_buffer.appendSlice(__c_expr_transform(rval.*)) catch @panic("could not append to return_buffer in __c_assign_stmt_transform\n"); 
        
    }

    return_buffer.append(';') catch @panic("could not append to return_buffer in __c_assign_stmt_transform\n"); 

    return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");

}

//
// update stmts like a += 200 + 300;
pub fn __c_update_stmt_transform(stmt: STATEMENTS) BUFFER {
    var return_buffer = std.ArrayList(u8).init(default_allocator);

    return_buffer.appendSlice(stmt.update.lvalue_name) catch @panic("could not append to return_buffer in __c_update_stmt_transform\n");
    return_buffer.appendSlice(__c_update_operator_transform(stmt.update.update_op)) catch @panic("could not append to return_buffer in __c_update_stmt_transform\n");
    return_buffer.appendSlice(__c_expr_transform(stmt.update.rvalue_expr.*)) catch @panic("could not append to return_buffer in __c_update_stmt_transform\n");
    return_buffer.append(';') catch @panic("could not append to return_buffer in __c_update_stmt_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");

}

// 
// singleton mapping
pub fn __c_break_stmt_transform(stmt: STATEMENTS) BUFFER {
    var return_buffer = std.ArrayList(u8).init(default_allocator);
    _ = stmt.break_stmt;

    return_buffer.appendSlice("break;") catch @panic("could not append to return_buffer in __c_break_stmt_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");

}

// 
// naked_stmts are stmts written and discarded
// for example, a + b + c;
// this line is eval and discarded, hence, it may be useful to 
// check for type sanity
pub fn __c_naked_stmt_transform(stmt: STATEMENTS) BUFFER {
    var return_buffer = std.ArrayList(u8).init(default_allocator);
    return_buffer.appendSlice(__c_expr_transform(stmt.naked_expr.inner_expr.*)) catch @panic("could not append to return_buffer in __c_update_stmt_transform\n");
    return_buffer.append(';') catch @panic("could not append to return_buffer in __c_update_stmt_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");

}

//
// heterogeneous admixture of STATEMENTS -> block
pub fn __c_block_stmt_transform(stmt: STATEMENTS) BUFFER {
    var return_buffer = std.ArrayList(u8).init(default_allocator);

    return_buffer.appendSlice(" { ") catch @panic("could not append to return_buffer in __c_block_stmt_transform\n");

    for(stmt.block.inner_elements.items) |blk_item| {
        return_buffer.appendSlice("\n\t") catch @panic("could not append to return_buffer in __c_block_stmt_transform\n");

        return_buffer.appendSlice(
            switch(blk_item) {
    
                .for_stmt => __c_for_stmt_transform(blk_item),
                .loop_stmt => __c_loop_stmt_transform(blk_item),
                .conditional_stmt => __c_conditional_stmt_transform(blk_item),
                .assignment => __c_assign_stmt_transform(blk_item),
                .update => __c_update_stmt_transform(blk_item),
                .block => __c_block_stmt_transform(blk_item),
                .naked_expr => __c_naked_stmt_transform(blk_item),
                .break_stmt => __c_break_stmt_transform(blk_item),


        }) catch @panic("could not append to return_buffer in __c_block_stmt_transform\n");

    }

    return_buffer.appendSlice("\n} ") catch @panic("could not append to return_buffer in __c_block_stmt_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");

}

/////////////////////// CODE-GEN STATEMENTS ///////////////////// end //////



////////////////////// CODE-GEN DEFINITIONS //////////////////// start ////

// when hoisting, the program only requires declaration
const HOIST = true;

//
// C_equiv of O_struct_def
// when writing a struct def, it is necessary for every field to be mutable
pub fn __c_struct_def_transform(strukt: DEFINITIONS, is_hoist: bool) BUFFER {
    var return_buffer = std.ArrayList(u8).init(default_allocator);

    return_buffer.appendSlice("struct ") catch @panic("could not append to return_buffer in __c_struct_def_transform\n");
    return_buffer.appendSlice(strukt.struct_def.struct_name) catch @panic("could not append to return_buffer in __c_struct_def_transform\n");
    if(is_hoist) {
        return_buffer.appendSlice(";\n") catch @panic("could not append to return_buffer in __c_struct_def_transform\n");
        return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");

    }

    return_buffer.appendSlice(" {\n") catch @panic("could not append to return_buffer in __c_struct_def_transform\n");

    // fields
    var fields_types_ = strukt.struct_def.fields_types.iterator();
    while(fields_types_.next()) |fields_types| {
        return_buffer.appendSlice(__c_types_transform(fields_types.value_ptr.*.*, IS_STRUCT_DEF)) catch @panic("could not append to return_buffer in __c_struct_def_transform\n");
        return_buffer.appendSlice(" ") catch @panic("could not append to return_buffer in __c_struct_def_transform\n");
        return_buffer.appendSlice(fields_types.key_ptr.*) catch @panic("could not append to return_buffer in __c_struct_def_transform\n");
        return_buffer.appendSlice(";\n") catch @panic("could not append to return_buffer in __c_struct_def_transform\n");
    }

    return_buffer.appendSlice("};\n") catch @panic("could not append to return_buffer in __c_struct_def_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");

}

// 
// C_equiv of O_enum_def
pub fn __c_enum_def_transform(__enum: DEFINITIONS, is_hoist: bool) BUFFER {
    var return_buffer = std.ArrayList(u8).init(default_allocator);

    return_buffer.appendSlice("enum ") catch @panic("could not append to return_buffer in __c_enum_def_transform\n");
    return_buffer.appendSlice(__enum.enum_def.enum_name) catch @panic("could not append to return_buffer in __c_enum_def_transform\n");
    if(is_hoist) {
        return_buffer.appendSlice(";\n") catch @panic("could not append to return_buffer in __c_enum_def_transform\n");
        return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");

    }

    return_buffer.appendSlice(" {\n") catch @panic("could not append to return_buffer in __c_enum_def_transform\n");

    // fields
    for(__enum.enum_def.fields.items) |field| {
        return_buffer.appendSlice(field) catch @panic("could not append to return_buffer in __c_enum_def_transform\n");
        return_buffer.appendSlice(",\n") catch @panic("could not append to return_buffer in __c_enum_def_transform\n");
    }
   
    return_buffer.appendSlice("};\n") catch @panic("could not append to return_buffer in __c_enum_def_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");

}

//
// C_equiv of O_fn_def
pub fn __c_fn_def_transform(func: DEFINITIONS, is_hoist: bool) BUFFER {
    var return_buffer = std.ArrayList(u8).init(default_allocator);

    return_buffer.appendSlice("auto ") catch @panic("could not append to return_buffer in __c_fn_def_transform\n");
    return_buffer.appendSlice(func.function_def.fn_name) catch @panic("could not append to return_buffer in __c_fn_def_transform\n");
    return_buffer.appendSlice(__c_types_transform(func.function_def.fn_type.*, IS_FN_DEF)) catch @panic("could not append to return_buffer in __c_fn_def_transform\n");
    if(is_hoist) {
        return_buffer.appendSlice(";\n") catch @panic("could not append to return_buffer in __c_fn_def_transform\n");
        return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");

    }

    return_buffer.appendSlice(__c_block_stmt_transform(func.function_def.fn_block)) catch @panic("could not append to return_buffer in __c_fn_def_transform\n");

    return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");

}



////////////////////// CODE-GEN DEFINITIONS //////////////////// end //////


///////////////////// CODE-GEN TYPES ////////////////////////// start ////

const IS_STRUCT_DEF: bool = true;
const IS_FN_DEF: bool = true;

//
// transforms all types
pub fn __c_types_transform(types: TYPES, is_struct_def: bool) BUFFER {
    var return_buffer = std.ArrayList(u8).init(default_allocator);

    switch(types) {
        
        .void => 
        {
            if(!types.void.mut and !is_struct_def) { return_buffer.appendSlice("const ") catch @panic("could not append to return_buffer in __c_types_transform\n"); }
            return_buffer.appendSlice("void") catch @panic("could not append to return_buffer in __c_types_transform\n");
        },

        .number =>
        {
            if(!types.number.mut and !is_struct_def) { return_buffer.appendSlice("const ") catch @panic("could not append to return_buffer in __c_types_transform\n"); }
            return_buffer.appendSlice(map_internal_types(types.number.focused_type)) catch @panic("could not append to return_buffer in __c_types_transform\n"); 
            
        },

        .string =>
        {
            if(!types.string.mut and !is_struct_def) { return_buffer.appendSlice("const ") catch @panic("could not append to return_buffer in __c_types_transform\n"); }
            return_buffer.appendSlice(map_internal_types("String")) catch @panic("could not append to return_buffer in __c_types_transform\n"); 
        },

        .char =>
        {
            if(!types.char.mut and !is_struct_def) { return_buffer.appendSlice("const ") catch @panic("could not append to return_buffer in __c_types_transform\n"); }
            return_buffer.appendSlice(map_internal_types("char")) catch @panic("could not append to return_buffer in __c_types_transform\n"); 
        },

        .pointer =>
        {
            // if(!types.pointer.mut and !is_struct_def) { return_buffer.appendSlice("const ") catch @panic("could not append to return_buffer in __c_types_transform\n"); }
            const ptr_to = __c_types_transform(types.pointer.ptr_to.*, is_struct_def);

            return_buffer.appendSlice(ptr_to) catch @panic("could not append to return_buffer in __c_types_transform\n");
            return_buffer.appendSlice("* ") catch @panic("could not append to return_buffer in __c_types_transform\n");

        },

        .reference =>
        {
            // if(!types.reference.mut and !is_struct_def) { return_buffer.appendSlice("const ") catch @panic("could not append to return_buffer in __c_types_transform\n"); }
            const ref_to = __c_types_transform(types.reference.reference_to.*, is_struct_def);

            return_buffer.appendSlice(ref_to) catch @panic("could not append to return_buffer in __c_types_transform\n");
            return_buffer.appendSlice("& ") catch @panic("could not append to return_buffer in __c_types_transform\n");

        },

        // compiles to cpp-container-array
        .array =>
        {
            if(!types.array.mut and !is_struct_def) { return_buffer.appendSlice("const ") catch @panic("could not append to return_buffer in __c_types_transform\n"); }
            const array_len = types.array.len orelse "8";
            const array_data_type = __c_types_transform(types.array.lonely_type.*, is_struct_def);
        
            return_buffer.appendSlice("array< ") catch @panic("could not append to return_buffer in __c_types_transform\n");
            return_buffer.appendSlice(array_data_type) catch @panic("could not append to return_buffer in __c_types_transform\n");
            return_buffer.appendSlice(",  ") catch @panic("could not append to return_buffer in __c_types_transform\n");
            return_buffer.appendSlice(array_len) catch @panic("could not append to return_buffer in __c_types_transform\n");
            return_buffer.appendSlice(" >") catch @panic("could not append to return_buffer in __c_types_transform\n");


        },

        .record =>
        {
            if(!types.record.mut and !is_struct_def) { return_buffer.appendSlice("const ") catch @panic("could not append to return_buffer in __c_types_transform\n"); }
            return_buffer.appendSlice(types.record.record_name) catch @panic("could not append to return_buffer in __c_types_transform\n");
        },

        // functions are transformed to match 
        // auto add(int a, int b) -> int { .. } semantics
        .function =>
        {
            return_buffer.appendSlice("( ") catch @panic("could not append to return_buffer in __c_types_transform\n");
            if(types.function.args_and_types) |aat| {
                var iter = aat.iterator();
                while(iter.next()) |aat_p| {
                    return_buffer.appendSlice(__c_types_transform(aat_p.value_ptr.*.*, !IS_STRUCT_DEF)) catch @panic("could not append to return_buffer in __c_types_transform\n");
                    return_buffer.appendSlice(" ") catch @panic("could not append to return_buffer in __c_types_transform\n");
                    return_buffer.appendSlice(aat_p.key_ptr.*) catch @panic("could not append to return_buffer in __c_types_transform\n");
                    return_buffer.appendSlice(", ") catch @panic("could not append to return_buffer in __c_types_transform\n");
                }

                // trailing commas
                _ = return_buffer.pop();
                _ = return_buffer.pop();
            } 

            return_buffer.appendSlice(" )") catch @panic("could not append to return_buffer in __c_types_transform\n");
            return_buffer.appendSlice(" -> ") catch @panic("could not append to return_buffer in __c_types_transform\n");
            
            const return_type = __c_types_transform(types.function.return_type.*, is_struct_def); 
            return_buffer.appendSlice(return_type) catch @panic("could not append to return_buffer in __c_types_transform\n");
            
        },

    }


    return return_buffer.toOwnedSlice() catch @panic("could not own slice pointed by buffer\n");

}



///////////////////// CODE-GEN TYPES ////////////////////////// end //////


////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////// CODE GEN ////////////////////////// CODE GEN ////////////////////////// CODE GEN ////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

test {
    print("-- TEST TRANSFORM LITERALS\n", .{});

    var parser = Parser.init_for_tests("^a.b.c");
    const types = parser.parse_literals();

    print("{s}\n", .{__c_literal_transform(types)});

    print("passed..\n\n", .{});
}

test {
    print("-- TEST TRANSFORM LITERALS\n", .{});

    var parser = Parser.init_for_tests("a.b[100]");
    const types = parser.parse_literals();

    print("{s}\n", .{__c_literal_transform(types)});

    print("passed..\n\n", .{});
}

test {
    print("-- TEST TRANSFORM EXPR\n", .{});

    var parser = Parser.init_for_tests("logger { .level = 0, .warn = \"yes\", .err = 1 + s + 3,};");
    const expr = parser.parse_expr();

    print("{s}\n", .{__c_expr_transform(expr.*)});

    print("passed..\n\n", .{});
}

test {
    print("-- TEST TRANSFORM EXPR\n", .{});

    var parser = Parser.init_for_tests("a + 2 + 3;");
    const expr = parser.parse_expr();

    print("{s}\n", .{__c_expr_transform(expr.*)});

    print("passed..\n\n", .{});
}

test {
    print("-- TEST TRANSFORM STATEMENTS\n", .{});

    var parser = Parser.init_for_tests("for i in a + 100: x.y[200] : {}");
    const stmt = parser.parse_for_stmt();

    print("{s}\n", .{__c_for_stmt_transform(stmt.*)});

    print("passed..\n\n", .{});
}

test {
    print("-- TEST TRANSFORM STATEMENTS\n", .{});

    const s = 
    \\ if a + 200 == 500 : { }
    \\ elif a + 200 == 600 : { }
    \\ elif a + 200 == 700 : { }
    \\ else : { }
    ;

    var parser = Parser.init_for_tests(s);
    const stmt = parser.parse_if_stmt();

    print("{s}\n", .{__c_conditional_stmt_transform(stmt.*)});

    print("passed..\n\n", .{});
}

test {
    print("-- TEST TRANSFORM STATEMENTS\n", .{});

    const s = 
    \\ {
    \\ number += number;
    \\ for number in number >> 2: number >> 4: { n += 6; }
    \\ }
    ;

    var parser = Parser.init_for_tests(s);
    const stmt = parser.parse_block();

    print("{s}\n", .{__c_block_stmt_transform(stmt)});

    print("passed..\n\n", .{});
}

test {
    print("-- TEST TRANSFORM TYPES\n", .{});

    const tp = "proc(a :: @int, b :: @int) int";

    var parser = Parser.init_for_tests(tp);
    const tpp = parser.parse_type();

    print("{s}\n", .{__c_types_transform(tpp.*, !IS_STRUCT_DEF)});

    print("passed..\n\n", .{});
}

test {
    print("-- TEST FUNCTION_DEF\n", .{});
    
    const s = 
    \\ add :: proc() int {
    \\      return a + b;
    \\ };
    ;

    var parser = Parser.init_for_tests(s);
    const fn_def = parser.parse_fn_def();

    print("{s}\n", .{__c_fn_def_transform(fn_def, true)});

    
    print("passed..\n\n", .{});
}

test {
    print("-- TEST EMIT_PROGRAM\n", .{});

    var parser = Parser.raw_init_with_file("./file.ox");
    const program = parser.parse_program();


    print("{s}", .{__c_hoist_declarations(program)});

    print("passed..\n\n", .{});
}

test {
    print("-- TEST EMIT_PROGRAM\n", .{});

    var parser = Parser.raw_init_with_file("./exa.ox");
    const program = parser.parse_program();

    const emitter = EMIT.with("somefile.cpp", 11);

    __emit_program(program, emitter);

    print("passed..\n\n", .{});
}
