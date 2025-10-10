/////////////////////////////////////////////////////////////////////
/////// TOKENS /////////////// TOKENS /////////////// TOKENS ////////
/////////////////////////////////////////////////////////////////////

//
// Individual token instance
pub const Token = struct {
    kind: token_id,
    lexeme: ?[]const u8,

    // pos, and line number in source file
    span: [2]u32, 
};

//
// All token definitions
pub const token_id = enum {

    ////////////// 1. KEYWORDS /////////////// start //

    keyword_break,
    keyword_case,
    keyword_mut,
    keyword_else,
    keyword_enum,
    keyword_for,
    keyword_in,
    keyword_if,
    keyword_elif,
    keyword_return,
    keyword_struct,
    keyword_switch,
    keyword_while,
    keyword_function,
    keyword_and,
    keyword_or,
    keyword_loop,

    //////////////// KEYWORDS //////////////// end ////





    /////////////// 2. TYPES ///////////////// start // 

    type_u8,
    type_u16,
    type_u32, 

    type_i8,
    type_i16,
    type_i32, 
    type_i64,
    type_int,

    type_f32,
    type_f64,
    type_f128,

    type_void,

    type_char,
    type_string,
    type_reference, 
    type_pointer, // ^
    type_array,
    type_maybe, 
    type_none, 
    type_error,
    type_namespace, 

    ////////////////// TYPES ///////////////// end //// 





    ///////////// 3. LITERALS ///////////////// start //

    literal_number, 
    literal_float, 
    literal_char, 
    literal_string, 

    //////////////// LITERALS ///////////////// end ////





    /////////// 4. DIRECTIVES ////////////// start ///

    directive_include,
    directive_import, 
    directive_alias,
    directive_aliased_word,
    directive_mod,
    directive_inline,
    directive_static,
    
    ////////////// DIRECTIVES ////////////// end ////





    //////////// 5. BASE-SYMBOLS //////////// start //

    base_identifier,
    base_left_paren,
    base_right_paren,
    base_left_braces,
    base_right_braces,
    base_left_bracket,
    base_right_bracket,
    base_comma,
    base_bitwise_and, 
    base_bitwise_or, 
    base_type_colon,
    base_colon,
    base_semicolon,
    base_dot,
    base_add,
    base_mul,
    base_sub,
    base_div,
    base_exp, 
    base_mod,
    base_assign, 
    base_equal, 
    base_not_equal,
    base_lt,
    base_gt,
    base_le,
    base_ge,
    base_left_shift, 
    base_right_shift, 
    base_EOF,

    ////////////// BASE-SYMBOLS //////////// end /////





    ////////// 6. COMMON-MEANING-SYMS /////// start ///

    common_exclamation, // maybe and negate both look like '!'

    //////////// COMMON-MEANING-SYMS /////// end /////
};
