///// According to ./GrammarOrthodox
///////////////////////////////////////////////////////////////
///////////////////////// PARSER //////////////////////////////
///////////////////////////////////////////////////////////////


const StreamLexer = @import("./lexer.zig").StreamLexer;
const tokens = @import("./tokens.zig");
const Token = tokens.Token;
const token_id = tokens.token_id;

const std = @import("std");
const print = std.debug.print;

const AST = @import("./AST.zig");
const TYPES = AST.TYPES;
const LITERALS = AST.LITERALS;
const EXPRESSIONS = AST.EXPRESSIONS;
const OPERATORS = AST.OPERATORS;
const UPDATE_OPERATORS = AST.UPDATE_OPERATORS;
const STATEMENTS = AST.STATEMENTS;
const DEFINITIONS = AST.DEFINITIONS;

pub usingnamespace token_id;
pub usingnamespace TYPES;

const DEFAULT_INTEGER_TYPE_STRING = "i32";
const DEFAULT_FLOAT_TYPE_STRING   = "f64";

pub const Parser = struct {

    //
    // StreamLexer.next_token should be called till exhaustion
    stream_tokens: std.ArrayList(Token),
    current_token_idx: ?usize,

    //
    // stream_tokens.items.len
    var LEN_STREAM_TOKENS: usize = undefined;

    const Self = @This();

    //
    // default allocator throughout the Parser,
    // deallocated only when program exits
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    const default_allocator = gpa.allocator();

    //
    // initialize with a filename to read
    // extract from StreamLexer to stream_tokens till exhaustion
    pub fn raw_init_with_file(filename: []const u8) Self {
        var lexer = StreamLexer.init_with_file(filename);
        var parser = Self {
            .stream_tokens = std.ArrayList(Token).init(Self.default_allocator),
            .current_token_idx = null,
        };

        while(true) {
            const token = lexer.next_token();
            parser.stream_tokens.append(token) catch @panic("Could not facilitate all tokens in stream_tokens\n");

            if(token.kind == .base_EOF) break;
        }

        Self.LEN_STREAM_TOKENS = parser.stream_tokens.items.len;
        return parser;
    }

    pub fn init_for_tests(source: []const u8) Self {
        var lexer = StreamLexer.raw_init(source, "");
        var parser = Self {
            .stream_tokens = std.ArrayList(Token).init(Self.default_allocator),
            .current_token_idx = null,
        };

        while(true) {
            const token = lexer.next_token();
            parser.stream_tokens.append(token) catch @panic("Could not facilitate all tokens in stream_tokens\n");

            if(token.kind == .base_EOF) break;
        }

        Self.LEN_STREAM_TOKENS = parser.stream_tokens.items.len;
        return parser;
    }


    /////////////////// PARSE-PROGRAM ///////////////////////// start ////////////////

    //
    // a program consists of a sequence of struct | enum | function definitions
    pub fn parse_program(self: *Self) std.ArrayList(DEFINITIONS) {

        var program = std.ArrayList(DEFINITIONS).init(Self.default_allocator);

        while(!self.expect_token(.base_EOF)) {

            self.expect_advance_token(.base_identifier); // struct | enum | fn name
            self.expect_advance_token(.base_type_colon);


            const tok = self.peek_token();
            switch(tok.kind) {

                .keyword_struct =>
                {
                    self.putback_token(); // .base_type_colon
                    self.putback_token(); // struct_name

                    const struct_def = self.parse_struct_def();
                    program.append(struct_def) catch @panic("could not append struct_def to program");

                },

                .keyword_enum =>
                {
                    self.putback_token(); // .base_type_colon
                    self.putback_token(); // enum_name

                    const enum_def = self.parse_enum_def();
                    program.append(enum_def) catch @panic("could not append enum_def to program");

                },

                .keyword_function =>
                {
                    self.putback_token(); // .base_type_colon
                    self.putback_token(); // fn_name

                    const fn_def = self.parse_fn_def();
                    program.append(fn_def) catch @panic("could not append fn_def to program");

                },

                else =>
                @panic("only, struct | enum | function def are allowed in a program\n"),

            }


        }

        return program;

    }

    /////////////////// PARSE-PROGRAM ///////////////////////// end //////////////////


    //
    // All types are parsed here
    pub fn parse_type(self: *Self) *TYPES { // VERIFIED

        // To keep *TYPES valid even after returning from function
        const return_type_ptr = Self.default_allocator.create(TYPES) catch @panic("Unable to allocate memory in parse_type\n");

        var this_type: TYPES = undefined;

        var type_is_mut = false;
        if(self.expect_token(.keyword_mut)) {
            type_is_mut = true;
            self.advance_token();
        }

        const tok = self.peek_token();
        switch(tok.kind) {



            ////////////////////// NUMBERS ////////////////////// start //

            .type_i8 => {
                this_type = TYPES {
                    .number = .{
                        .focused_type = "i8",
                        .mut = type_is_mut,
                    }
                };
            },

            .type_i16 => {
                this_type = TYPES {
                    .number = .{
                        .focused_type = "i16",
                        .mut = type_is_mut,
                    }
                };
            },

            .type_i32 => {
                this_type = TYPES {
                    .number = .{
                        .focused_type = "i32",
                        .mut = type_is_mut,
                    }
                };
            },

            .type_i64 => {
                this_type = TYPES {
                    .number = .{
                        .focused_type = "i64",
                        .mut = type_is_mut,
                    }
                };
            },

            .type_u8 => {
                this_type = TYPES {
                    .number = .{
                        .focused_type = "u8",
                        .mut = type_is_mut,
                    }
                };
            },

            .type_u16 => {
                this_type = TYPES {
                    .number = .{
                        .focused_type = "u16",
                        .mut = type_is_mut,
                    }
                };
            },

            .type_u32 => {
                this_type = TYPES {
                    .number = .{
                        .focused_type = "u32",
                        .mut = type_is_mut,
                    }
                };
            },

            .type_f32 => {
                this_type = TYPES {
                    .number = .{
                        .focused_type = "f32",
                        .mut = type_is_mut,
                    }
                };
            },

            .type_f64 => {
                this_type = TYPES {
                    .number = .{
                        .focused_type = "f64",
                        .mut = type_is_mut,
                    }
                };
            },

            .type_f128 => {
                this_type = TYPES {
                    .number = .{
                        .focused_type = "f128",
                        .mut = type_is_mut,
                    }
                };
            },

            ////////////////////// NUMBERS ///////////////////////// end /




            .type_char => {
                this_type = TYPES {
                    .char = .{
                        .mut = type_is_mut,
                    }
                };
            },

            .type_string => {
                this_type = TYPES {
                    .string = .{
                        .mut = type_is_mut,
                    }
                };
            },

            .type_void => {
                this_type = TYPES {
                    .void = .{
                        .mut = type_is_mut,
                    }
                };
            },


            ///////////////// PTR, REF, ARRAYS  ////////////////// start /

            .type_pointer => { // pointer type
                // in cases we have know that peek'ing token returns a fixed token, we call advance_token instead of expect_advance_token
                self.advance_token();

                this_type = TYPES {
                    .pointer = .{
                        .ptr_to = self.parse_type(), // after calling parse_type call putback_token ~ parse_type advance_token' before returning
                        .mut = type_is_mut,
                    }
                };

                self.putback_token();
            },

            .type_reference => {
                self.advance_token();

                this_type = TYPES {
                    .reference = .{
                        .reference_to = self.parse_type(),
                        .mut = type_is_mut,
                    }
                };

                self.putback_token();
            },

            .base_left_bracket => { // array types
                self.advance_token();

                // arrays can not have expressions as part of their types
                // number :: [1 + (2-3 ** (2 == 0)) + if(x==0) { break 5; }]i32 = {}
                // does not work for obvious reasons
                //
                // checking: "mut"? "[" SIZE "]" LONELY_TYPE
                if(self.expect_token(.literal_number) == false) {
                    @panic("array type with no size is not allowed, originating in parse_type\n");
                }

                const size = self.peek_token().lexeme.?;
                self.advance_token();

                if(self.expect_token(.base_right_bracket) == false) {
                    @panic("unterminated '[' in array type, originating in parse_types\n");
                }

                self.advance_token();

                this_type = TYPES {
                    .array = .{
                        .len = size,
                        .lonely_type = self.parse_type(),
                        .mut = type_is_mut,
                    }
                };

                self.putback_token();
            },

            ///////////////// PTR, REF, ARRAYS  //////////////////// end /





            //////////////// STRUCT, ENUMS (RECORDS) ///////////// start ///

            .base_identifier => {
                const record_name = tok.lexeme.?;

                this_type = TYPES {
                    .record = .{
                        .record_name = record_name,
                        .mut = type_is_mut,
                    }
                };
            },

            //////////////// STRUCT, ENUMS (RECORDS) //////////////// end///



            ///////////// FUNCTION TYPES ////////////////////////// start //

            .keyword_function => {

                self.expect_advance_token(.keyword_function);
                self.expect_advance_token(.base_left_paren);

                var args_and_types = std.StringHashMap(*TYPES).init(Self.default_allocator);

                var no_args = true;

                while(true) {
                    if(self.expect_token(.base_right_paren)) {
                        self.expect_advance_token(.base_right_paren);
                        break;
                    }

                    const arg_name = self.peek_token().lexeme.?;
                    self.expect_advance_token(.base_identifier);

                    self.expect_advance_token(.base_type_colon);

                    const arg_type = self.parse_type();

                    no_args = false;
                    args_and_types.put(arg_name, arg_type) catch @panic("could not put to args_and_types in parse_types\n");

                    if(!self.expect_token(.base_comma)) {
                        self.expect_advance_token(.base_right_paren);
                        break;
                    }

                    self.expect_advance_token(.base_comma);

                }

                const fn_return_type = self.parse_type();
                self.putback_token();

                if(no_args) {
                    this_type = TYPES {
                        .function = .{
                            .args_and_types = null,
                            .return_type = fn_return_type,
                        }
                    };
                } else {
                    this_type = TYPES {
                        .function = .{
                            .args_and_types = args_and_types,
                            .return_type = fn_return_type,
                        }
                    };

                }



            },

            ///////////// FUNCTION TYPES ////////////////////////// end ////

            else => {
                print("got :: {any}\n", .{tok});
                @panic("panic in parse_types\n");
            },
        }

        self.advance_token();
        return_type_ptr.* = this_type;
        return return_type_ptr;

    }

    //
    // literals may appear in an expression
    // Parses all literals
    pub fn parse_literals(self: *Self) LITERALS {  // VERIFIED
        var return_literal: LITERALS = undefined;

        const tok = self.peek_token();
        switch(tok.kind) {

            .literal_number => {
                return_literal = LITERALS {
                    .number = .{
                        .inner_value = tok.lexeme.?,
                        .number_type_name = DEFAULT_INTEGER_TYPE_STRING,
                    }
                };
            },

            .literal_float => {
                return_literal = LITERALS {
                    .number = .{
                        .inner_value = tok.lexeme.?,
                        .number_type_name = DEFAULT_FLOAT_TYPE_STRING,
                    }
                };
            },

            .literal_string => {
                return_literal = LITERALS {
                    .string = .{
                        .inner_value = tok.lexeme.?,
                    }
                };
            },

            .literal_char => {
                return_literal = LITERALS {
                    .char = .{
                        .inner_value = tok.lexeme.?
                    }
                };
            },

            .base_identifier => {

                // check if this is a variable, or a struct/record member access
                self.advance_token();
                if(self.expect_token(.base_dot) == false) {
                    // normal variable
                    // undo the effect of the above advance_token
                    self.putback_token();

                    return_literal = LITERALS {
                        .variable = .{
                            .inner_value = tok.lexeme.?,
                        }
                    };

                } else {
                    // struct/enum member access
                    self.expect_advance_token(.base_dot);

                    var member_names = std.ArrayList([]const u8).init(Self.default_allocator);

                    while(true) {
                        const field_name = self.peek_token();
                        if(self.expect_token(.base_identifier) == false) @panic("expected member-name after '.' in member-access\n");

                        member_names.append(field_name.lexeme.?) catch @panic("could not extend member_names std.ArrayList in parse_literals\n");
                        self.advance_token();

                        if(self.expect_token(.base_dot) == false) break;
                        self.advance_token();
                    }

                    // putback here, only because at end of this function we always advance_token
                    self.putback_token();

                    return_literal = LITERALS {
                        .member_access = .{
                            .record_type_name = tok.lexeme.?,
                            .members_name_in_order = member_names,
                        }
                    };
                }
            },

            else => {
                @panic("non-literal type received in parse_literals\n");
            },
        }

        // check if followed by array-access syntax
        self.advance_token();

        const array_var = Self.default_allocator.create(LITERALS) catch @panic("unable to allocate memory in parse_literals\n");
        if(self.expect_token(.base_left_bracket)) { // array-access
            array_var.* = return_literal;

            self.expect_advance_token(.base_left_bracket);

            const access_index = self.parse_expr(); // parse_expr consumes ']'

            return_literal = LITERALS {
                .array_access = .{
                    .array_var = array_var,
                    .access_index = access_index,
                }
            };
        }

        return return_literal;
    }


    /////////////////// RECORDS - AND - FUNCTION DEFINITIONS /////// start ///

    pub fn parse_struct_def(self: *Self) DEFINITIONS {

        const struct_name = self.peek_token().lexeme.?;
        self.expect_advance_token(.base_identifier);

        self.expect_advance_token(.base_type_colon);
        self.expect_advance_token(.keyword_struct);

        // self.expect_advance_token(.base_assign);
        self.expect_advance_token(.base_left_braces);

        var fields_types = std.StringHashMap(*TYPES).init(Self.default_allocator);

        var is_struct_empty = true;
        while(true) {
            if(self.expect_token(.base_right_braces)) {
                self.expect_advance_token(.base_right_braces);
                break;
            }

            const field_name = self.peek_token().lexeme.?;
            self.expect_advance_token(.base_identifier);

            self.expect_advance_token(.base_type_colon);
            const field_type = self.parse_type();

            self.expect_advance_token(.base_comma);

            is_struct_empty = false;
            fields_types.put(field_name, field_type) catch @panic("can not append to fields_types in parse_struct_def\n");

        }

        if(is_struct_empty) @panic("struct with no fields is not allowed\n");

        if(!self.expect_token(.base_semicolon)) {
            @panic("struct-def should end with .base_semicolon");
        }

        self.expect_advance_token(.base_semicolon);

        return DEFINITIONS {
            .struct_def = .{
                .struct_name = struct_name,
                .fields_types = fields_types,
            }
        };


    }

    pub fn parse_enum_def(self: *Self) DEFINITIONS {

        const enum_name = self.peek_token().lexeme.?;
        self.expect_advance_token(.base_identifier);

        self.expect_advance_token(.base_type_colon);
        self.expect_advance_token(.keyword_enum);

        // self.expect_advance_token(.base_assign);
        self.expect_advance_token(.base_left_braces);

        var fields = std.ArrayList([]const u8).init(Self.default_allocator);

        var enum_is_empty = true;
        while(true) {
            if(self.expect_token(.base_right_braces)) {
                self.expect_advance_token(.base_right_braces);
                break;
            }

            const field_name = self.peek_token().lexeme.?;
            self.expect_advance_token(.base_identifier);

            enum_is_empty = false;
            fields.append(field_name) catch @panic("could not append to field_names in parse_enum_def\n");

            self.expect_advance_token(.base_comma);
        }

        if(enum_is_empty) @panic("enum with no fields is not allowed\n");

        if(!self.expect_token(.base_semicolon)) {
            @panic("enum-def must end with .base_semicolon");
        }

        self.expect_advance_token(.base_semicolon);

        return DEFINITIONS {
            .enum_def = .{
                .enum_name = enum_name,
                .fields = fields,
            }
        };


    }

    pub fn parse_fn_def(self: *Self) DEFINITIONS {

        const fn_name = self.peek_token().lexeme.?;
        self.expect_advance_token(.base_identifier);

        self.expect_advance_token(.base_type_colon);

        const fn_type = self.parse_type();

        // self.expect_advance_token(.base_assign);

        const fn_block = self.parse_block();

        if(!self.expect_token(.base_semicolon)) {
            @panic("function-def must end with .base_semicolon");
        }

        self.expect_advance_token(.base_semicolon);

        return DEFINITIONS {
            .function_def = .{
                .fn_name = fn_name,
                .fn_type = fn_type,
                .fn_block = fn_block,
            }
        };

    }

    /////////////////// RECORDS - AND - FUNCTION DEFINITIONS /////// end /////





    //////////////////////// SUB-EXPRESSIONS /////////////////////// start ///

    pub fn parse_literal_expr(self: *Self) *EXPRESSIONS {
        const literal_expr_ptr = Self.default_allocator.create(EXPRESSIONS) catch @panic("Unable to allocate memory in parse_literal_expr\n");

        literal_expr_ptr.* = EXPRESSIONS {
            .literal_expr = .{
                .inner_literal = self.parse_literals(),
                .inner_expr = self.parse_expr(),
            }
        };


        return literal_expr_ptr;

    }

    pub fn parse_op_expr(self: *Self) *EXPRESSIONS {
        const op_expr_ptr = Self.default_allocator.create(EXPRESSIONS) catch @panic("Unable to allocate memory in parse_op_expr\n");

        if(!self.peek_is_operator()) {
            @panic("parse_op_expr requires operator, at first");
        }

        var operator: OPERATORS = undefined;

        const tok = self.peek_token();
        switch(tok.kind) {
            .base_add => {
                operator = OPERATORS.ADD;
            },

            .base_sub => {
                operator = OPERATORS.MINUS;
            },

            .base_div => {
                operator = OPERATORS.DIVIDE;
            },

            .base_mul => {
                operator = OPERATORS.MULTIPLY;
            },

            .base_mod => {
                operator = OPERATORS.MOD;
            },

            .base_exp  => {
                operator = OPERATORS.EXP;
            },

            .base_left_shift => {
                operator = OPERATORS.LEFT_SHIFT;
            },

            .base_right_shift => {
                operator = OPERATORS.RIGHT_SHIFT;
            },

            .base_bitwise_and => {
                operator = OPERATORS.BITWISE_AND;
            },

            .base_bitwise_or => {
                operator = OPERATORS.BITWISE_OR;
            },

            .keyword_and => {
                operator = OPERATORS.AND;
            },

            .keyword_or => {
                operator = OPERATORS.OR;
            },

            .base_lt => {
                operator = OPERATORS.LT;
            },

            .base_gt => {
                operator = OPERATORS.GT;
            },

            .base_le => {
                operator = OPERATORS.LE;
            },

            .base_ge => {
                operator = OPERATORS.GE;
            },

            .base_equal => {
                operator = OPERATORS.EQUAL;
            },

            .base_not_equal => {
                operator = OPERATORS.NON_EQUAL;
            },

            else =>
            @panic("invalid operator in parse_fn_call_expr\n"),
        }

        self.advance_token();

        op_expr_ptr.* = EXPRESSIONS {
            .operator_expr = .{
                .inner_operator = operator,
                .inner_expr = self.parse_expr(),
            }
        };

        return op_expr_ptr;

    }

    pub fn parse_fn_call_expr(self: *Self) *EXPRESSIONS {
        const fn_expr_ptr = Self.default_allocator.create(EXPRESSIONS) catch @panic("Unable to allocate memory in parse_fn_call_expr\n");

        const fn_name = self.peek_token().lexeme.?;
        self.expect_advance_token(.base_identifier);
        self.expect_advance_token(.base_left_paren);

        var arg_list = std.ArrayList(*EXPRESSIONS).init(Self.default_allocator);

        while(true) {
            if(self.expect_token(.base_right_paren)) {
                self.expect_advance_token(.base_right_paren);
                break;
            }

            const arg = self.parse_expr();
            arg_list.append(arg) catch @panic("could not append to arg_list in parse_fn_call_expr\n");

            self.putback_token(); // parse_expr consumes both ',' and ')', when ')' is consumed, putback that token
            if(self.expect_token(.base_right_paren)) {
                self.expect_advance_token(.base_right_paren);
                break;
            }

            self.advance_token();
        }

        fn_expr_ptr.* = EXPRESSIONS {
            .fn_call_expr = .{
                .fn_name = fn_name,
                .inner_expr_list = arg_list,
                .then_expr = self.parse_expr(),
            }
        };

        return fn_expr_ptr;
    }

    pub fn parse_return_expr(self: *Self) *EXPRESSIONS {
        const return_expr_ptr = Self.default_allocator.create(EXPRESSIONS) catch @panic("Unable to allocate memory in parse_return_expr\n");

        self.expect_advance_token(.keyword_return);

        return_expr_ptr.* = EXPRESSIONS {
            .return_expr = .{
                .inner_expr = self.parse_expr(),
            }
        };

        return return_expr_ptr;

    }

    //
    // closed-expr are under paren ~ (a + b - (c ** d))
    // for expressions like ((x + y) + z) you might have to call this twice
    pub fn parse_closed_expr(self: *Self) *EXPRESSIONS {
        const closed_expr_ptr = Self.default_allocator.create(EXPRESSIONS) catch @panic("Unable to allocate memory in parse_closed_expr\n");

        self.expect_advance_token(.base_left_paren);
        closed_expr_ptr.* = EXPRESSIONS {
            .closed_expr = .{
                .inner_expr = self.parse_expr(),
            }
        };

        return closed_expr_ptr;

    }

    //
    // right side may only contain struct creation, and nothing else
    // struct_init require ',' after every field
    pub fn parse_struct_init_expr(self: *Self) *EXPRESSIONS {
        const struct_expr_ptr = Self.default_allocator.create(EXPRESSIONS) catch @panic("Unable to allocate memory in parse_struct_init_expr\n");
        var fields_values = std.StringHashMap(*EXPRESSIONS).init(Self.default_allocator);

        const struct_name = self.peek_token().lexeme.?;
        self.expect_advance_token(.base_identifier);
        self.expect_advance_token(.base_left_braces);

        while(true) {
            if(self.expect_token(.base_right_braces))  {
                self.expect_advance_token(.base_right_braces);
                break;
            }

            self.expect_advance_token(.base_dot);
            const field_name = self.peek_token().lexeme.?;
            self.expect_advance_token(.base_identifier);

            self.expect_advance_token(.base_assign);

            const field_value = self.parse_expr();
            switch(field_value.*) { // if a field inside a struct is init with a struct-def, '}' of that struct-def is used as delimiter for that struct ending, but we require, .base_comma after every field
                .struct_expr =>
                self.expect_advance_token(.base_comma),

                else =>
                {}
            }


            fields_values.put(field_name, field_value) catch @panic("could not 'put' to fields_values in parse_struct_init_expr\n");

            if(self.expect_token(.base_comma)) self.expect_advance_token(.base_comma);

        }

        self.expect_advance_token(.base_semicolon);

        struct_expr_ptr.* = EXPRESSIONS {
            .struct_expr = .{
                .struct_name = struct_name,
                .fields_values = fields_values,
            }
        };

        return struct_expr_ptr;
    }

    //////////////////////// SUB-EXPRESSIONS /////////////////////// end  ////





    /////////////////////// EXPRESSIONS /////////////////////////// start ///

    var NO_OF_PAREN_IN_CLOSED_EXPR : i32 = 0;

    //
    // parses expressions without consuming last token
    pub fn parse_expr(self: *Self) *EXPRESSIONS {
        var expr_ptr = Self.default_allocator.create(EXPRESSIONS) catch @panic("Unable to allocate memory in parse_closed_expr\n");
        expr_ptr.* = EXPRESSIONS.NULL;


        const tok = self.peek_token();
        switch(tok.kind) {

            .literal_number, .literal_float, .literal_char, .literal_string =>
            {
                expr_ptr  = self.parse_literal_expr();
            },

            .base_identifier => // could be fn_call or literal_expr or struct_init_expr
            {

                self.expect_advance_token(.base_identifier); // first skip id-name, if '(' appears, it is a fn_call expr
                if(self.expect_token(.base_left_paren)) { // fn_call expr
                    self.putback_token();
                    expr_ptr = self.parse_fn_call_expr();
                } else if(self.expect_token(.base_left_braces)) { // struct_init_expr
                    self.putback_token();
                    expr_ptr = self.parse_struct_init_expr();
                } else { // literal_expr
                    self.putback_token();
                    expr_ptr = self.parse_literal_expr();
                }

            },

            .keyword_return =>
            {
                expr_ptr = self.parse_return_expr();
            },

            .base_left_paren =>
            {
                NO_OF_PAREN_IN_CLOSED_EXPR += 1;
                expr_ptr = self.parse_closed_expr();
            },

            .base_right_paren =>
            {
                NO_OF_PAREN_IN_CLOSED_EXPR -= 1;
                self.expect_advance_token(.base_right_paren);
            },

            .base_add, .base_sub,
            .base_div, .base_mul,
            .base_exp, .base_mod,
            .base_equal, .base_not_equal,
            .base_lt, .base_gt,
            .base_le, .base_ge,
            .base_left_shift, .base_right_shift,
            .base_bitwise_and, .base_bitwise_or,
            .keyword_and, .keyword_or =>
            {
                expr_ptr = self.parse_op_expr();
            },

            // break cases
            .base_semicolon,  // ends stuff like a = 1 + 2 + 3;
            .base_comma, // in functions ~ add(1, b)
            .base_left_braces => // in stmts, like if 1 + 2 + 3 > 0 { .. }
            self.advance_token(),

            .base_colon => // in for-statement ~ for ID in EXPR ":" EXPR ..
            self.advance_token(),

            .base_right_bracket => // access array
            self.advance_token(),

            else =>
            {
                print("got token :: {any}\n", .{tok});
                @panic("unexpected token in parse_expr\n");
            },

        }

        return expr_ptr;

    }

    /////////////////////// EXPRESSIONS /////////////////////////// end /////



    //////////////////////// LOOP /////////////////////////// start ///


    fn parse_for_stmt(self: *Self) *STATEMENTS {

        self.expect_advance_token(.keyword_for);
        if(!self.expect_token(.base_identifier)) @panic("in for-loop, expected, identifier_name after .keyword_for\n");

        const identifier_name = self.peek_token().lexeme.?;
        self.expect_advance_token(.base_identifier);

        self.expect_advance_token(.keyword_in);

        const range_expr1 = self.parse_expr();
        const range_expr2 = self.parse_expr();

        const for_block_ptr = Self.default_allocator.create(STATEMENTS) catch @panic("unable to allocate memory in parse_for_stmt\n");
        for_block_ptr.* = self.parse_block();

        const return_for_block_ptr = Self.default_allocator.create(STATEMENTS) catch @panic("unable to allocate memory in parse_for_stmt\n");

        return_for_block_ptr.* = STATEMENTS {
            .for_stmt = .{
                .identifier_name = identifier_name,
                .range_expr1 = range_expr1,
                .range_expr2 = range_expr2,
                .for_block = for_block_ptr,
            }
        };

        return return_for_block_ptr;
    }

    pub fn parse_loop_stmt(self: *Self) *STATEMENTS {
        self.expect_advance_token(.keyword_loop);

        self.expect_advance_token(.base_colon);

        const loop_block_ptr = Self.default_allocator.create(STATEMENTS) catch @panic("unable to allocate memory in parse_for_stmt\n");
        loop_block_ptr.* = self.parse_block();

        const return_loop_block_ptr = Self.default_allocator.create(STATEMENTS) catch @panic("unable to allocate memory in parse_for_stmt\n");

        return_loop_block_ptr.* = STATEMENTS {
            .loop_stmt = .{
                .loop_block = loop_block_ptr,
            }
        };

        return return_loop_block_ptr;
    }



    //////////////////////// LOOP /////////////////////////// end ///





    ////////////////////// ASSIGNMENTS /////////////////////////// start ////


    //
    // assignments may be simple decl ~ a :: mut i32;
    // or, ~ a :: mut i32 = 1 + 2;
    pub fn parse_assign_stmt(self: *Self) STATEMENTS {

        const lvalue_name = self.peek_token().lexeme.?;
        self.expect_advance_token(.base_identifier);
        self.expect_advance_token(.base_type_colon);

        const lvalue_type = self.parse_type();

        if(!self.expect_token(.base_assign)) { // simple decl
            self.expect_advance_token(.base_semicolon);

            return STATEMENTS {
                .assignment = .{
                    .lvalue_name = lvalue_name,
                    .lvalue_type = lvalue_type,
                    .rvalue_expr = null,
                }
            };

        }


        self.expect_advance_token(.base_assign);

        const rvalue_expr = self.parse_expr();

        return STATEMENTS {
            .assignment = .{
                .lvalue_name = lvalue_name,
                .lvalue_type = lvalue_type,
                .rvalue_expr = rvalue_expr,
            }
        };

    }

    pub fn parse_var_update_stmt(self: *Self) STATEMENTS {

        const lvalue_name = self.peek_token().lexeme.?;
        self.expect_advance_token(.base_identifier);

        const update_op = self.which_update_operator();

        const rvalue_expr = self.parse_expr();

        return STATEMENTS {
            .update = .{
                .lvalue_name = lvalue_name,
                .update_op = update_op,
                .rvalue_expr = rvalue_expr,
            }
        };

    }


    ////////////////////// ASSIGNMENTS /////////////////////////// end /////




    ////////////////////// CONDITIONALS ///////////////////////// start ////

    pub fn parse_if_stmt(self: *Self) *STATEMENTS {

        const return_if_ptr = Self.default_allocator.create(STATEMENTS) catch @panic("Unable to allocate memory in parse_if_stmt\n");

        var has_elif_branches = false;
        var elif_conds = std.ArrayList(*EXPRESSIONS).init(Self.default_allocator);
        var elif_blocks = std.ArrayList(*STATEMENTS).init(Self.default_allocator);

        self.expect_advance_token(.keyword_if);

        const if_cond = self.parse_expr();

        const if_block = Self.default_allocator.create(STATEMENTS) catch @panic("Unable to allocate memory in parse_if_stmt\n");
        if_block.* = self.parse_block();

        // elif branches?
        while(true) { // assume there are branches, and correct that assumption
            if(!self.expect_token(.keyword_elif)) break;
            has_elif_branches = true;

            self.expect_advance_token(.keyword_elif);

            const elif_cond = self.parse_expr();
            const elif_block = Self.default_allocator.create(STATEMENTS) catch @panic("Unable to allocate memory in parse_if_stmt\n");
            elif_block.* = self.parse_block();

            elif_conds.append(elif_cond) catch @panic("could not append to elif_conds in parse_if_stmt\n");
            elif_blocks.append(elif_block) catch @panic("could not append to elif_conds in parse_if_stmt\n");

        }

        var has_else = false;
        const else_blk: *STATEMENTS = Self.default_allocator.create(STATEMENTS) catch @panic("Unable to allocate memory in parse_if_stmt\n");

        // else branch?
        if(self.expect_token(.keyword_else)) {
            has_else = true;

            self.expect_advance_token(.keyword_else);
            self.expect_advance_token(.base_colon);

            else_blk.* = self.parse_block();
        }


        if(has_elif_branches) {
            return_if_ptr.* = STATEMENTS {
                .conditional_stmt = .{
                    .if_cond = if_cond,
                    .if_block = if_block,

                    .elif_conds = elif_conds,
                    .elif_blocks = elif_blocks,

                    .else_block = if(has_else) else_blk else null,
                }
            };
        } else {
            return_if_ptr.* = STATEMENTS {
                .conditional_stmt = .{
                    .if_cond = if_cond,
                    .if_block = if_block,

                    .elif_conds = null,
                    .elif_blocks = null,

                    .else_block = if(has_else) else_blk else null,
                }
            };
        }

        return return_if_ptr;

    }

    ////////////////////// CONDITIONALS ///////////////////////// end //////





    //////////////////////// BLOCK ///////////////////////////// start /////

    pub fn parse_block(self: *Self) STATEMENTS {

        var block_elem = std.ArrayList(STATEMENTS).init(Self.default_allocator);

        self.expect_advance_token(.base_left_braces);

        while(true) {
            const tok = self.peek_token();
            switch(tok.kind) {

                // nested block_stmt
                .base_left_braces =>
                {
                    const block = self.parse_block();
                    block_elem.append(block) catch @panic("can not append to block_elem\n");
                },


                .base_right_braces =>
                break,


                // assignment, update
                .base_identifier =>
                {
                    _  = self.expect_advance_token(.base_identifier);

                    if(self.expect_token(.base_type_colon)) { // assignment
                        self.putback_token();
                        const assign_stmt = self.parse_assign_stmt();
                        block_elem.append(assign_stmt) catch @panic("can not append to block_elem\n");

                    } else if(self.peek_is_operator()) {
                        const which_op = self.peek_token().kind;
                        self.advance_token();

                        if(which_op != .base_assign) {
                            if(self.expect_token(.base_assign)) { // update
                                self.putback_token();
                                self.putback_token();
                                const var_stmt = self.parse_var_update_stmt();
                                block_elem.append(var_stmt) catch @panic("can not append to block_elem\n");

                            } else { // expr can occur in blocks
                                const expr_in_block = STATEMENTS {
                                    .naked_expr = .{
                                        .inner_expr = self.parse_expr(),
                                    }
                                };

                                block_elem.append(expr_in_block) catch @panic("can not append to block_elem\n");
                            }
                        } else { // update by assignment
                            self.putback_token();
                            self.putback_token();
                            const var_stmt = self.parse_var_update_stmt();
                            block_elem.append(var_stmt) catch @panic("can not append to block_elem\n");
                        }

                    } else { // expr can occur in blocks
                        self.putback_token();

                        const expr_in_block = STATEMENTS {
                            .naked_expr = .{
                                .inner_expr = self.parse_expr(),
                            }
                        };

                        block_elem.append(expr_in_block) catch @panic("can not append to block_elem\n");
                    }
                },

                // for-stmt
                .keyword_for =>
                {
                    const for_stmt = self.parse_for_stmt();
                    block_elem.append(for_stmt.*) catch @panic("can not append to block_elem\n");
                },

                // loop-stmt
                .keyword_loop =>
                {
                    const loop_stmt = self.parse_loop_stmt();
                    block_elem.append(loop_stmt.*) catch @panic("can not append to block_elem\n");
                },

                // if-stmt
                .keyword_if =>
                {
                    const if_stmt = self.parse_if_stmt();
                    block_elem.append(if_stmt.*) catch @panic("can not append to block_elem\n");
                },

                // break is a stmt
                .keyword_break =>
                {
                    self.expect_advance_token(.keyword_break);
                    self.expect_advance_token(.base_semicolon);

                    const break_blk = STATEMENTS.break_stmt;
                    block_elem.append(break_blk) catch @panic("can not append to block_elem\n");
                },

                else => {
                    const expr_in_block = STATEMENTS {
                        .naked_expr = .{
                            .inner_expr = self.parse_expr(),
                        }
                    };

                    block_elem.append(expr_in_block) catch @panic("can not append to block_elem\n");
                },

            }
        }

        self.expect_advance_token(.base_right_braces);

        return STATEMENTS {
           .block = .{
                .inner_elements = block_elem,
            }
        };

    }

    //////////////////////// BLOCK ///////////////////////////// end ///////


    //
    // is peek_token a binary-operator
    pub fn peek_is_operator(self: *Self) bool {

        switch(self.peek_token().kind) {

            .base_assign, // used in update_op along with '+/-/...'
            .base_add, .base_sub,
            .base_div, .base_mul,
            .base_exp, .base_mod,
            .base_equal, .base_not_equal,
            .base_lt, .base_gt,
            .base_le, .base_ge,
            .base_left_shift, .base_right_shift,
            .base_bitwise_and, .base_bitwise_or,
            .keyword_and, .keyword_or =>
            return true,

            else =>
            return false,

        }

    }

    //
    // which update-op is next, consume it
    pub fn which_update_operator(self: *Self) UPDATE_OPERATORS {

        if(self.expect_token(.base_assign))  {
            self.expect_advance_token(.base_assign);
            return UPDATE_OPERATORS.ASSIGN;

        }

        const operator = self.peek_token().kind;
        self.advance_token(); // consume - operator in '-='
        self.expect_advance_token(.base_assign); // OPERATOR should precede .base_assign in update-op

        return switch(operator) {
            .base_add => UPDATE_OPERATORS.ADD_EQ,
            .base_sub => UPDATE_OPERATORS.MINUS_EQ,
            .base_mul => UPDATE_OPERATORS.MUL_EQ,
            .base_div => UPDATE_OPERATORS.DIV_EQ,
            .base_mod => UPDATE_OPERATORS.MOD_EQ,
            .base_exp => UPDATE_OPERATORS.EXP_EQ,
            .base_left_shift => UPDATE_OPERATORS.LEFT_SHIFT_EQ,
            .base_right_shift => UPDATE_OPERATORS.RIGHT_SHIFT_EQ,
            .base_bitwise_and => UPDATE_OPERATORS.BITWISE_AND_EQ,
            .base_bitwise_or => UPDATE_OPERATORS.BITWISE_OR_EQ,

            else => @panic("this should not be possible, only to satisfy the semantics, in which_update_operator\n"),
        };

    }

    //
    // look at next token without consuming it
    pub fn peek_token(self: *Self) Token {
        if(self.current_token_idx) |idx| {
            if(idx + 1 > Self.LEN_STREAM_TOKENS) @panic("out-of-index access in peek_token\n");
            return self.stream_tokens.items[idx + 1];
        } else {
            // self.current_token_idx = 1;
            return self.stream_tokens.items[0];
        }
    }

    //
    // Shorthand for
    // if expect_token(SOME_TOKEN_ID) then, advance_token()
    pub fn expect_advance_token(self: *Self, kind: token_id) void {
        if(self.expect_token(kind)) return self.advance_token();

        print("Expected {any}, got {any}\n", .{kind, self.peek_token().kind});
        @panic("expect_token returned false in expect_advance_token\n");
    }

    //
    // Expect next_token to be of 'kind'
    // Does not advance stream_tokens
    pub fn expect_token(self: *Self, kind: token_id) bool {
        return (kind == self.peek_token().kind);
    }

    //
    // Advance to next_token by consuming current_token
    // Do not return Token, like peek_token or current_token
    pub fn advance_token(self: *Self) void {
        if(self.current_token_idx) |_| {
            self.current_token_idx.? += 1;
            if(self.current_token_idx.? > Self.LEN_STREAM_TOKENS) @panic("exceeded stream_tokens.len in advance_token()\n");
        } else self.current_token_idx = 0;
    }

    //
    // undo the effect of an individual advance_token
    pub fn putback_token(self: *Self) void {
        if(self.current_token_idx) |idx| {
            if(idx > 0) { self.current_token_idx.? -= 1; }
            else self.current_token_idx = null;
        }
    }

    //
    // shows stream_tokens.items[from..to]
    pub fn show_token_list(self: *Self, from: usize, to: usize) void {
        if (to > Self.LEN_STREAM_TOKENS) {
            @panic("out-of-index in stream_tokens\n");
        }

        for(self.stream_tokens.items[from..to]) |item| {
            print("{any}\n", .{item});
        }
    }

    pub fn show_full_token_list(self: *Self) void {
        return self.show_token_list(0, Self.LEN_STREAM_TOKENS);
    }

    //
    // clean-up procedures
    pub fn dealloc(self: *Self) void {
        self.stream_tokens.deinit();
    }
};

///////////////////////////////////////////////////////////////////////////////////////
/////// PARSER TESTS /////////////// PARSER TESTS /////////////// PARSER TESTS ////////
///////////////////////////////////////////////////////////////////////////////////////

// test {
//     print("-- TEST LITERALS\n", .{});
//     var parser = Parser.init_for_tests("0;");
//
//     _ = parser.parse_literals();
//
//     print("{any}\n", .{parser.peek_token().kind});
//
//     print("passed..\n\n", .{});
//
// }
//
// test {
//     print("-- TEST POINTER TYPES\n", .{});
//     var parser = Parser.init_for_tests("mut^ [100]some_struct");
//
//     const parsed = parser.parse_type();
//
//     print("{any}\n", .{parsed});
//
//     print("{any}\n", .{parser.peek_token().kind});
//
//     print("passed..\n\n", .{});
//
// }
//
// test {
//     print("-- TEST PARSE EXPRESSIONS\n", .{});
//     var parser = Parser.init_for_tests("a+1; x; c-d;");
//
//     var parsed = parser.parse_expr();
//     print("1 :: {s} {any} {s}\n", .{
//         parsed.literal_expr.inner_literal.variable.inner_value,
//         parsed.literal_expr.inner_expr.operator_expr.inner_operator,
//         parsed.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal.number.inner_value
//     });
//
//     parsed = parser.parse_expr();
//     print("2 :: {s}\n", .{parsed.literal_expr.inner_literal.variable.inner_value});
//
//     parsed = parser.parse_expr();
//     print("3 :: {s} {any} {s}\n", .{
//         parsed.literal_expr.inner_literal.variable.inner_value,
//         parsed.literal_expr.inner_expr.operator_expr.inner_operator,
//         parsed.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal.variable.inner_value
//     });
//
//
//
//     print("passed..\n\n", .{});
//
// }
//
// test {
//     print("-- TEST PARSE CLOSED EXPRESSIONS\n", .{});
//     var parser = Parser.init_for_tests("return (1 + (c+d));");
//
//     const parsed = parser.parse_expr();
//     print("( ", .{});
//     print("{s} ", .{parsed.return_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_literal.number.inner_value});
//     print("{any} ", .{parsed.return_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_operator});
//     print("( ", .{});
//     print("{s} ", .{parsed.return_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_literal.variable.inner_value});
//     print("{any} ", .{parsed.return_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_operator});
//     print("{s}", .{parsed.return_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal.variable.inner_value});
//     print(" ) ", .{});
//     print(" )\n ", .{});
//
//
//     print("passed..\n\n", .{});
//
// }
//
// test {
//     print("-- TEST PARSE FUNCTION EXPRESSIONS\n", .{});
//     var parser = Parser.init_for_tests("add('c', 2 + number, number + 2);");
//
//     const parsed = parser.parse_expr();
//     _ = parsed;
//
//     print("{any}\n", .{parser.peek_token().kind});
//
//     print("passed..\n\n", .{});
//
// }
//
// test {
//     print("-- TEST PARSE LOOP STATMENTS\n", .{});
//     var parser = Parser.init_for_tests("loop : { a = x + 100; }");
//
//     const parsed = parser.parse_loop_stmt();
//     const loop_parsed = parsed.loop_stmt.loop_block.block.inner_elements.items[0];
//
//     print("<{s}> <{any}> <{s}> <{any}> <{s}>\n", .{
//         loop_parsed.update.lvalue_name,
//         loop_parsed.update.update_op,
//         loop_parsed.update.rvalue_expr.literal_expr.inner_literal.variable.inner_value,
//         loop_parsed.update.rvalue_expr.literal_expr.inner_expr.operator_expr.inner_operator,
//         loop_parsed.update.rvalue_expr.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal.number.inner_value,
//     });
//
//     print("passed..\n\n", .{});
//
// }
//
// test {
//     print("-- TEST PARSE FOR STATMENTS\n", .{});
//     var parser = Parser.init_for_tests("for x in ZERO : ONE >> 32 : { a = x + 100; }");
//
//     const parsed = parser.parse_for_stmt();
//     const for_parsed = parsed.for_stmt;
//
//     print("for <{s}> in <{s}> : <{s}> <{any}> <{s}>\n", .{
//             for_parsed.identifier_name,
//             for_parsed.range_expr1.literal_expr.inner_literal.variable.inner_value,
//             for_parsed.range_expr2.literal_expr.inner_literal.variable.inner_value,
//             for_parsed.range_expr2.literal_expr.inner_expr.operator_expr.inner_operator,
//             for_parsed.range_expr2.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal.number.inner_value,
//     });
//
//     const for_parsed_blk = for_parsed.for_block.block.inner_elements.items[0];
//     print("<{s}> <{any}> <{s}> <{any}> <{s}>\n", .{
//         for_parsed_blk.update.lvalue_name,
//         for_parsed_blk.update.update_op,
//         for_parsed_blk.update.rvalue_expr.literal_expr.inner_literal.variable.inner_value,
//         for_parsed_blk.update.rvalue_expr.literal_expr.inner_expr.operator_expr.inner_operator,
//         for_parsed_blk.update.rvalue_expr.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal.number.inner_value,
//     });
//
//     print("passed..\n\n", .{});
//
// }
//
// test {
//     print("-- TEST PARSE STRUCT-INIT-EXPR\n", .{});
//     var parser = Parser.init_for_tests("numbers {.a = b, .b = 200, .c = math { .pi = 3.14, };, .d = 0, };");
//
//     const parsed = parser.parse_expr();
//     _ = parsed;
//
//
//     print("passed..\n\n", .{});
//
// }
//
// test {
//     print("-- TEST PARSE ASSIGNMENT\n", .{});
//     var parser = Parser.init_for_tests("a :: mut i32 = 1 + 2; b :: i64 = 128; c :: String;");
//
//     var parsed = parser.parse_assign_stmt();
//
//     print("lvalue_name :: {s}\n", .{parsed.assignment.lvalue_name});
//     print("lvalue_type :: {any}\n", .{parsed.assignment.lvalue_type});
//     print("rvalue_expr :: {any}\n", .{parsed.assignment.rvalue_expr});
//
//     parsed = parser.parse_assign_stmt();
//
//     print("lvalue_name :: {s}\n", .{parsed.assignment.lvalue_name});
//     print("lvalue_type :: {any}\n", .{parsed.assignment.lvalue_type});
//     print("rvalue_expr :: {any}\n", .{parsed.assignment.rvalue_expr});
//
//     parsed = parser.parse_assign_stmt();
//
//     print("lvalue_name :: {s}\n", .{parsed.assignment.lvalue_name});
//     print("lvalue_type :: {any}\n", .{parsed.assignment.lvalue_type});
//     print("rvalue_expr :: {any}\n", .{parsed.assignment.rvalue_expr});
//
//
//     print("passed..\n\n", .{});
//
// }
//
//
// test {
//     print("-- TEST PARSE STRUCT ASSIGNMENT\n", .{});
//     var parser = Parser.init_for_tests("d :: mut logger = logger { .level = 0, .warn = a.b.c.d.e, };");
//
//     const parsed = parser.parse_assign_stmt();
//     _ = parsed;
//
//     print("{any} :: \n", .{parser.peek_token()});
//
//     print("passed..\n\n", .{});
//
// }
//
// test {
//     print("-- TEST PARSE WHICH UPDATE-OP\n", .{});
//     var parser = Parser.init_for_tests("+= -= = **= >>= <<= *=");
//
//     var parsed = parser.which_update_operator();
//     print("{any}\n", .{parsed});
//
//     parsed = parser.which_update_operator();
//     print("{any}\n", .{parsed});
//
//     parsed = parser.which_update_operator();
//     print("{any}\n", .{parsed});
//
//     parsed = parser.which_update_operator();
//     print("{any}\n", .{parsed});
//
//     parsed = parser.which_update_operator();
//     print("{any}\n", .{parsed});
//
//     parsed = parser.which_update_operator();
//     print("{any}\n", .{parsed});
//
//     parsed = parser.which_update_operator();
//     print("{any}\n", .{parsed});
//
//     print("passed..\n\n", .{});
//
// }
//
// test {
//     print("-- TEST PARSE  UPDATE_OP\n", .{});
//
//     const s =
//     \\ temp_logger = logger {
//     \\      .which = file {
//     \\         .number = stdout {
//     \\            .yes  = yes,
//     \\            .buffer = "IONBF",
//     \\            .time = timespec {
//     \\                .nsec = 100,
//     \\                .sec = 200 + 300,
//     \\            };,
//     \\         };,
//     \\       };,
//     \\ };
//     ;
//
//     var parser = Parser.init_for_tests(s);
//
//     const parsed = parser.parse_var_update_stmt();
//     print("{any}\n", .{parsed});
//
//     print("{any}\n", .{parser.peek_token()});
//
//
//     print("passed..\n\n", .{});
//
// }
//
// test {
//     print("-- TEST PARSE BLOCK_EXPR\n", .{});
//
//     var parser = Parser.init_for_tests("{ c :: mut i32 = 1; c += 100; { e :: String; } }");
//     const parsed = parser.parse_block();
//
//     const parsed_blk = parsed.block.inner_elements.items;
//     print("{any}\n", .{parsed_blk[0]});
//     print("{any}\n", .{parsed_blk[1]});
//     print("{any}\n", .{parsed_blk[2].block.inner_elements.items[0]});
//
//     print("passed..\n\n", .{});
// }
//
// test {
//     print("-- TEST PARSE BLOCK_EXPR\n", .{});
//
//     var parser = Parser.init_for_tests("{ c :: mut i32 = 1; c += 100 + 200; for i in 0 : 100 : { s = \"stringosis\"; } }");
//     const parsed = parser.parse_block();
//
//     const parsed_blk = parsed.block.inner_elements.items;
//     print("{any}\n", .{parsed_blk[0]});
//     print("{any}\n", .{parsed_blk[1]});
//     print("{any}\n", .{parsed_blk[2].for_stmt});
//
//     print("passed..\n\n", .{});
// }
//
// test {
//     print("-- TEST PARSE IF_EXPR\n", .{});
//
//     const s =
//     \\ if i >> 32 - 2000 : {
//     \\      c :: mut i32 = 0;
//     \\ } elif IS_THIS_VAR_TRUE : {
//     \\      d = 100;
//     \\ } elif THIS_VAR_IS_TRUE : {
//     \\     e = "string";
//     \\ } else : { x :: i32 = 1; x += 1; }
//     \\
//     ;
//
//     var parser = Parser.init_for_tests(s);
//     const parsed = parser.parse_if_stmt();
//     _ = parsed;
//
//     print("{any}\n", .{parser.peek_token().kind});
//
//     print("passed..\n\n", .{});
// }
//
// test {
//     print("-- TEST PARSE TOP_LVL STRUCT_DEF\n", .{});
//
//     const s =
//     \\ logger :: struct {
//     \\      level :: String,
//     \\      panic :: u8,
//     \\      which :: mut [1024][1024]i32,
//     \\ };
//     ;
//
//     var parser = Parser.init_for_tests(s);
//     const parsed = parser.parse_struct_def();
//     _ = parsed;
//
//     print("{any}\n", .{parser.peek_token().kind});
//
//     print("passed..\n\n", .{});
// }
//
// test {
//     print("-- TEST PARSE TOP_LVL ENUM_DEF\n", .{});
//
//     const s =
//     \\ level :: enum {
//     \\      NONE,
//     \\      ERR,
//     \\      FATAL,
//     \\      PANIC,
//     \\ };
//     ;
//
//     var parser = Parser.init_for_tests(s);
//     const parsed = parser.parse_enum_def();
//     _ = parsed;
//
//     print("{any}\n", .{parser.peek_token().kind});
//
//     print("passed..\n\n", .{});
// }
//
// test {
//     print("-- TEST PARSE FUNCTION-TYPE\n", .{});
//
//     const s = "proc(x :: String, y :: @String) mut [1024]u8";
//
//     var parser = Parser.init_for_tests(s);
//     const parsed = parser.parse_type().function;
//
//     var args_types = parsed.args_and_types.?.iterator();
//
//     while(args_types.next()) |item| {
//         print("{s} :: {any}\n", .{item.key_ptr.*, item.value_ptr.*});
//     }
//
//     print("returns :: {any}\n", .{parsed.return_type});
//
//     print("{any}\n", .{parser.peek_token().kind});
//
//     print("passed..\n\n", .{});
// }
//
// test {
//     print("-- TEST PARSE TOP_LVL FUNCTION_DEF\n", .{});
//
//     const s =
//     \\ main :: proc(args :: u32, argv :: [1024]String) void { loop : { a :: i32; } };
//     ;
//
//     var parser = Parser.init_for_tests(s);
//     const parsed = parser.parse_fn_def();
//     _ = parsed;
//
//     print("{any}\n", .{parser.peek_token().kind});
//
//     print("passed..\n\n", .{});
// }
//
// test {
//     print("-- test array-access\n", .{});
//
//     var parser = Parser.init_for_tests("some[i]");
//     const arr = parser.parse_literals().array_access;
//
//     print("{any}[{any}]\n", .{arr.array_var, arr.access_index});
//
//     print("passed..\n\n", .{});
// }
//
// test {
//     print("-- test array-access\n", .{});
//
//     var parser = Parser.init_for_tests("some[i];");
//     const arr = parser.parse_expr().literal_expr;
//
//     print("{any}\n", .{arr});
//     print("{any}\n", .{parser.peek_token().kind});
//
//     print("passed..\n\n", .{});
// }
//
// test {
//     print("-- TEST COMPLETE_PROGRAM\n", .{});
//
//     var parser = Parser.raw_init_with_file("./file.ox");
//     const parsed = parser.parse_program();
//
//     print("len :: {d}\n", .{parsed.items.len});
//     print("{any}\n", .{parsed.items[4]});
//     print("passed..\n\n", .{});
// }
//
// test {
//     print("-- TEST PARSE_FUNCTION_EXPR\n", .{});
//
//     var parser = Parser.init_for_tests("a + get_name(c - d) + fifty;");
//     const expr = parser.parse_expr();
//
//     const literal_expr = expr.literal_expr;
//     print("{s}\t", .{literal_expr.inner_literal.variable.inner_value});
//
//     const literal_inner_expr = literal_expr.inner_expr;
//     print("{any}\t", .{literal_inner_expr.operator_expr.inner_operator});
//
//     const operator_expr = literal_inner_expr.operator_expr.inner_expr.fn_call_expr;
//     print("{s}\t", .{operator_expr.fn_name});
//
//     const arg1 = operator_expr.inner_expr_list.items[0].literal_expr.inner_literal.variable.inner_value;
//     print("{s}\t", .{arg1});
//
//     const fn_op = operator_expr.inner_expr_list.items[0].literal_expr.inner_expr.operator_expr.inner_operator;
//     print("{any}\t", .{fn_op});
//
//     const arg2 = operator_expr.inner_expr_list.items[0].literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal.variable.inner_value;
//     print("{s}\t", .{arg2});
//
//     const then_expr = operator_expr.then_expr;
//     print("{any}\t", .{then_expr.operator_expr.inner_operator});
//     print("{s}\t", .{then_expr.operator_expr.inner_expr.literal_expr.inner_literal.variable.inner_value});
//
//
//     print("\n", .{});
//     print("passed..\n\n", .{});
// }
