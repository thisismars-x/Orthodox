/////// According to ./GrammarOrthodox
///////////////////////////////////////////////
///// Abstract Syntax Tree For ORthodox ///////
///////////////////////////////////////////////

const std = @import("std");

// 
// All types in ORthodox
pub const TYPES = union(enum) {
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
    // all arrays need to be sized,
    // number_array: []i32 = {1, 2, 3} will not work
    // number_array: [512]i32 = {1, 2, 3} will work
    array: struct {
        len: []const u8,
        lonely_type: *TYPES, // lonely_type of [1024]i32 is i32
        mut: bool,
    },

    //
    // structs and enums are record-types
    record: struct {
        record_name: []const u8,
        mut: bool,
    },
};


pub const EXPRESSION = union(enum) {
    literals: LITERALS,
};

pub const LITERALS = union(enum) {
    number: struct { // default type for number is type_i32 if integer, else type_f64 
        number_type_name: []const u8,
        inner_value: []const u8,
    },

    string: struct {
        inner_value: []const u8,
    },

    variable: struct {
        inner_value: []const u8, // name of variable
    },

    member_access: struct { // member access for record-types(enums and structs)
        record_type_name: []const u8,
        members_name_in_order: std.ArrayList([]const u8),
    }
};

