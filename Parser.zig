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
const BLOCK_ELEMENTS = AST.BLOCK_ELEMENTS;

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



            ///////////////// PTR, REF, ARRAYS  ////////////////// start /

            .common_mul => { // pointer type
                // in cases we have know that peek'ing token returns a fixed token, we call advance_token instead of expect_advance_token
                self.advance_token(); 

                this_type = TYPES {
                    .pointer = .{
                        .ptr_to = self.parse_type(),
                        .mut = type_is_mut,
                    }   
                };
            },

            .type_reference => {
                self.advance_token();

                this_type = TYPES {
                    .reference = .{
                        .reference_to = self.parse_type(),
                        .mut = type_is_mut,
                    }
                };
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

                while(true) {
                    
                    const tok2 = self.peek_token();
                    if(tok2.kind == .base_right_paren) break;

                    self.expect_advance_token(.base_identifier);
                    const fn_param_name = tok2.lexeme.?;

                    const type_param = self.parse_type();
                    
                    args_and_types.put(fn_param_name, type_param) catch @panic("could not add to args_and_types in parse_types\n");
                    if(self.expect_token(.base_comma) == false) break;

                    self.expect_advance_token(.base_comma);
                }

                this_type = TYPES {
                    .function = .{
                        .args_and_types = args_and_types,
                    }
                };

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

        self.advance_token();
        return return_literal;
    }


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

            else => @panic("TODO:: add other operators"),
            
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

        if(!self.expect_token(.base_identifier)) {
            @panic("expected .base_identifier in parse_fn_call_expr\n");
        } // fn_name

        const fn_name = self.peek_token().lexeme.?;
        self.advance_token();

        self.expect_advance_token(.base_left_paren);

        var arg_list = std.ArrayList(*EXPRESSIONS).init(Self.default_allocator);

        // arg-list
        while(true) {

            // in parse_expr, .base_right_paren / .base_comma / .base_semicolon are consumed,
            // hence putback, to check if token was ')' marking end of function call
            self.putback_token();
            if(self.expect_token(.base_right_paren)) break;
            self.advance_token();

            const inner_expr = self.parse_expr();
            print("{any}\n", .{inner_expr});
            arg_list.append(inner_expr) catch @panic("could not append to arg_list in parse_fn_call_expr\n");
        }

        fn_expr_ptr.* = EXPRESSIONS {
            .fn_call_expr = .{
                .fn_name = fn_name,
                .inner_expr_list = arg_list,
            }
        };
        
        return fn_expr_ptr;

    }

    pub fn parse_break_expr(self: *Self) *EXPRESSIONS {
        const break_expr_ptr = Self.default_allocator.create(EXPRESSIONS) catch @panic("Unable to allocate memory in parse_break_expr\n"); 
        
        self.expect_advance_token(.keyword_break);

        break_expr_ptr.* = EXPRESSIONS {
            .break_expr = .{
                .inner_expr = self.parse_expr(),
            }
        };

        return break_expr_ptr;

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

            .base_identifier => // could be fn_call or literal_expr
            {

                self.expect_advance_token(.base_identifier); // first skip id-name, if '(' appears, it is a fn_call expr
                if(self.expect_token(.base_left_paren)) { // fn_call expr
                    self.putback_token();
                    expr_ptr = self.parse_fn_call_expr();
                } else {
                    self.putback_token();
                    expr_ptr = self.parse_literal_expr();
                }

            },

            .keyword_break => 
            {
                expr_ptr = self.parse_break_expr();
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

            .base_add, .base_sub =>
            {
                expr_ptr = self.parse_op_expr();
            },

            // break cases
            .base_semicolon,  // ends stuff like a = 1 + 2 + 3;
            .base_comma, // in functions ~ add(1, b)
            .base_left_braces => // in stmts, like if 1 + 2 + 3 > 0 { .. }
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



    //////////////////////// STATEMENTS /////////////////////////// start ///

    //////////////////////// STATEMENTS /////////////////////////// start ///




    //
    // is peek_token a binary-operator
    pub fn peek_is_operator(self: *Self) bool {
        
        switch(self.peek_token().kind) {
            
            .base_add, .base_sub,
            .base_div, .common_mul,
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
        if(self.is_update_operator() == false) @panic("is_update_operator returned false, in which_update_operator\n");

        const operator = self.peek_token().kind;
        self.advance_token(); // consume - operator
        self.expect_advance_token(.base_assign); // OPERATOR should precede .base_assign in update-op

        return switch(operator) {
            .base_add => UPDATE_OPERATORS.ADD_EQ,
            .base_sub => UPDATE_OPERATORS.MINUS_EQ,
            .common_mul => UPDATE_OPERATORS.MUL_EQ,
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
    // is peek_token an update-operator
    pub fn is_update_operator(self: *Self) bool {

        const is_op = self.is_operator();
        if(is_op == false) return false;

        // a and= 6, is not valid, nor is a or= 7
        const tok = self.peek_token().kind;
        if((tok == .keyword_and) or (tok == .keyword_or)) return false;

        self.advance_token();

        const tok1 = self.peek_token().kind;
        if(tok1 == .base_assign) {
            self.putback_token();
            return true;

        } else {
            self.putback_token();
            return false;

        }

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

test {
    print("-- TEST LITERALS\n", .{});
    var parser = Parser.init_for_tests("A.B.C;");
    
    _ = parser.parse_literals();

    print("{any}\n", .{parser.peek_token().kind});

    print("passed..\n\n", .{});

}

test {
    print("-- TEST PARSE EXPRESSIONS\n", .{});
    var parser = Parser.init_for_tests("a+b; c-d;");

    var parsed = parser.parse_expr();
    print("1 :: {s} {any} {s}\n", .{
        parsed.literal_expr.inner_literal.variable.inner_value,
        parsed.literal_expr.inner_expr.operator_expr.inner_operator,
        parsed.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal.variable.inner_value
    });

    parsed = parser.parse_expr();
    print("2 :: {s} {any} {s}\n", .{
        parsed.literal_expr.inner_literal.variable.inner_value,
        parsed.literal_expr.inner_expr.operator_expr.inner_operator,
        parsed.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal.variable.inner_value
    });



    print("passed..\n\n", .{});

}

test {
    print("-- TEST PARSE CLOSED EXPRESSIONS\n", .{});
    var parser = Parser.init_for_tests("return (1 + (c+d));");

    const parsed = parser.parse_expr();
    print("( ", .{});
    print("{s} ", .{parsed.return_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_literal.number.inner_value});
    print("{any} ", .{parsed.return_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_operator});
    print("( ", .{});
    print("{s} ", .{parsed.return_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_literal.variable.inner_value});
    print("{any} ", .{parsed.return_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_operator});
    print("{s}", .{parsed.return_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_expr.closed_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal.variable.inner_value});
    print(" ) ", .{});
    print(" )\n ", .{});


    print("passed..\n\n", .{});

}

test {
    print("-- TEST PARSE FUNCTION EXPRESSIONS\n", .{});
    var parser = Parser.init_for_tests("add('c', number, number + 2);");

    const parsed = parser.parse_expr();
    _ = parsed;

    print("passed..\n\n", .{});

}
