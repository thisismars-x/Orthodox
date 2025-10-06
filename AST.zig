/////// According to ./GrammarOrthodox
///////////////////////////////////////////////
///// Abstract Syntax Tree For ORthodox ///////
///////////////////////////////////////////////

const std = @import("std");

// 
// All types in ORthodox
pub const TYPES = union(enum) {

    void: struct {
        mut: bool,
    },

    number: struct {
        focused_type: []const u8, // u8? i64? f32?
        mut: bool,
    },

    string: struct {
        mut: bool,
    },

    char: struct {
        mut: bool,
    },

    pointer: struct {
        ptr_to: *TYPES,
        mut: bool,
    },

    reference: struct {
        reference_to: *TYPES,
        mut: bool,
    },

    // 
    // number_array:: []i32 = {1, 2, 3} will work
    // number_array:: [512]i32 = {1, 2, 3} will work
    array: struct {
        len: ?[]const u8,
        lonely_type: *TYPES, // lonely_type of [1024]i32 is i32
        mut: bool,
    },

    //
    // structs and enums are record-types
    record: struct {
        record_name: []const u8,
        mut: bool,
    },

    function: struct { 
        args_and_types: ?std.StringHashMap(*TYPES),
        return_type: *TYPES, 
    },
};

pub const DEFINITIONS = union(enum) {

    struct_def: struct {
        struct_name: []const u8,
        fields_types: std.StringHashMap(*TYPES),
    },

    enum_def: struct {
        enum_name: []const u8,
        fields: std.ArrayList([]const u8),
    },

    function_def: struct {
        fn_name: []const u8,
        fn_type: *TYPES,
        fn_block: STATEMENTS,
    },


};


pub const EXPRESSIONS = union(enum) {

    NULL,

    literal_expr: struct {
        inner_literal: LITERALS,
        inner_expr: *EXPRESSIONS,
    },

    operator_expr: struct {
        inner_operator: OPERATORS,
        inner_expr: *EXPRESSIONS,
    },

    fn_call_expr: struct {
        fn_name: []const u8,
        inner_expr_list: std.ArrayList(*EXPRESSIONS),
        then_expr: *EXPRESSIONS, // in a + b(c -d) + f, +f is then_expr
    },

    return_expr: struct {
        inner_expr: *EXPRESSIONS,
    },

    closed_expr: struct {
        inner_expr: *EXPRESSIONS,
    },

    struct_expr: struct {
        struct_name: []const u8,
        fields_values: std.StringHashMap(*EXPRESSIONS),
    },

};

pub const STATEMENTS = union(enum) {

    for_stmt: struct {
        identifier_name: []const u8,
        range_expr1: *EXPRESSIONS,
        range_expr2: *EXPRESSIONS,
        for_block: *STATEMENTS,
    },

    loop_stmt: struct {
        loop_block: *STATEMENTS,
    },

    conditional_stmt: struct {
        if_cond: *EXPRESSIONS,
        if_block: *STATEMENTS,

        elif_conds: ?std.ArrayList(*EXPRESSIONS),
        elif_blocks: ?std.ArrayList(*STATEMENTS),

        else_block: ?*STATEMENTS,
    },

    assignment: struct {
        lvalue_name: []const u8,
        lvalue_type: *TYPES,
        rvalue_expr: ?*EXPRESSIONS,
    },

    update: struct {
        lvalue_name: []const u8,
        update_op: UPDATE_OPERATORS,
        rvalue_expr: *EXPRESSIONS,
    },

    block: struct {
        inner_elements: std.ArrayList(STATEMENTS),
    },

    naked_expr: struct {
        inner_expr: *EXPRESSIONS,
    },

    break_stmt,

};

pub const UPDATE_OPERATORS = enum {
    
    ASSIGN,
    ADD_EQ,
    MINUS_EQ,
    MUL_EQ,
    DIV_EQ,
    MOD_EQ,
    EXP_EQ,
    LEFT_SHIFT_EQ,
    RIGHT_SHIFT_EQ,
    BITWISE_AND_EQ,
    BITWISE_OR_EQ,

};

pub const OPERATORS = enum {

    ADD,
    MINUS,
    MULTIPLY, 
    DIVIDE,
    MOD,
    EXP,
    LEFT_SHIFT,
    RIGHT_SHIFT,
    BITWISE_AND,
    BITWISE_OR,
    AND,
    OR,

    LT,
    GT,
    LE,
    GE,

    EQUAL,
    NON_EQUAL,

};

pub const LITERALS = union(enum) {
    number: struct { // default type for number is type_i32 if integer, else type_f64 
        number_type_name: []const u8,
        inner_value: []const u8,
    },

    string: struct {
        inner_value: []const u8,
    },

    char: struct {
        inner_value: []const u8,
    },

    variable: struct {
        inner_value: []const u8, // name of variable
    },

    member_access: struct { // member access for record-types(enums and structs)
        record_type_name: []const u8,
        members_name_in_order: std.ArrayList([]const u8),
    },

    pointer_deref: struct {
        deref_literal: *LITERALS, // but may not be number, string, char
    },

    // array access are only allowed to one-level
    // x.y.z[100][200][300] just complicates life
    // instead: a :: mut i32 = x.y.z[100]; a = a[200]; a = a[300];
    array_access: struct { // access array's access-index'th index
        array_var: *LITERALS,
        access_index: *EXPRESSIONS,
    }
};

