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
    pub fn parse_type(self: *Self) *TYPES {

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
    pub fn parse_literals(self: *Self) LITERALS {
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
                    if(self.expect_token(.base_dot) == false) {
                        print("Expected .base_dot, got {any} instead\n", .{self.peek_token().kind});
                        @panic("expect_token failed in parse_literals\n");
                    }

                    self.advance_token();

                    var member_names = std.ArrayList([]const u8).init(Self.default_allocator);

                    while(true) {
                        const field_name = self.peek_token();
                        member_names.append(field_name.lexeme.?) catch @panic("could not extend member_names std.ArrayList in parse_literals\n");
                        self.advance_token();

                        if(self.expect_token(.base_dot) == false) break;
                        self.advance_token();
                    }

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

        
    pub fn parse_expr(self: *Self) *EXPRESSIONS {
        const return_expr_ptr = Self.default_allocator.create(EXPRESSIONS) catch @panic("Unable to allocate memory in parse_type\n"); 
        var this_expr: EXPRESSIONS = undefined;

        // 
        // parse any expression ending in ; , )
        while(true) {

            const tok = self.peek_token();
            switch(tok.kind) {

                .literal_number => {
                    const inner_literal = self.parse_literals();

                    this_expr = EXPRESSIONS {
                        .literal_expr = .{
                            .inner_literal = inner_literal,
                            .inner_expr = self.parse_expr(),
                        }
                    };
                },

                .literal_float => {
                    const inner_literal = self.parse_literals();

                    this_expr = EXPRESSIONS {
                        .literal_expr = .{
                            .inner_literal = inner_literal,
                            .inner_expr = self.parse_expr(),
                        }
                    };
                },

                .literal_string => {
                    const inner_literal = self.parse_literals();

                    this_expr = EXPRESSIONS {
                        .literal_expr = .{
                            .inner_literal = inner_literal,
                            .inner_expr = self.parse_expr(),
                        }
                    };
                },


                //
                // could be either record member access, or fn-expr
                .base_identifier => {
                    
                    self.expect_advance_token(.base_identifier);
                    const tok1 = self.peek_token();

                    // fn-expr
                    if(tok1.kind == .base_left_paren) {
                        const fn_name = tok.lexeme.?;
                        self.expect_advance_token(.base_left_paren);

                        var arg_list = std.ArrayList(*EXPRESSIONS).init(Self.default_allocator);

                        while(true) {
                            
                            // no args
                            if(self.expect_token(.base_right_paren)) {
                                break;

                            }

                            const arg_expr = self.parse_expr();
                            arg_list.append(arg_expr) catch @panic("could not add to arg_list in parse_expr\n");

                            if(self.expect_token(.base_comma)) self.advance_token();

                        }

                        this_expr = EXPRESSIONS {
                            .fn_call_expr = .{
                                .fn_name = fn_name,
                                .inner_expr_list = arg_list,
                            }
                        };

                    } else { // record member-access
                        self.putback_token();

                        const inner_literal = self.parse_literals();

                        this_expr = EXPRESSIONS {
                            .literal_expr = .{
                                .inner_literal = inner_literal,
                                .inner_expr = self.parse_expr(),
                            }
                        };

                    } 
                },




                /////////////////////// OPERATOR-EXPR ///////////////// start ////

                .base_add => {
                    const inner_operator = OPERATORS.ADD;
                    self.advance_token();

                    const inner_expr = self.parse_expr();

                    this_expr = EXPRESSIONS {
                        .operator_expr = .{
                            .inner_operator = inner_operator,
                            .inner_expr = inner_expr,
                        }
                    };
                },

                .base_sub => {
                    const inner_operator = OPERATORS.MINUS;
                    self.advance_token();

                    const inner_expr = self.parse_expr();

                    this_expr = EXPRESSIONS {
                        .operator_expr = .{
                            .inner_operator = inner_operator,
                            .inner_expr = inner_expr,
                        }
                    };
                },

                .base_div => {
                    const inner_operator = OPERATORS.DIVIDE;
                    self.advance_token();

                    const inner_expr = self.parse_expr();

                    this_expr = EXPRESSIONS {
                        .operator_expr = .{
                            .inner_operator = inner_operator,
                            .inner_expr = inner_expr,
                        }
                    };
                },

                .base_mod => {
                    const inner_operator = OPERATORS.MOD;
                    self.advance_token();

                    const inner_expr = self.parse_expr();

                    this_expr = EXPRESSIONS {
                        .operator_expr = .{
                            .inner_operator = inner_operator,
                            .inner_expr = inner_expr,
                        }
                    };
                },

                .base_exp => {
                    const inner_operator = OPERATORS.EXP;
                    self.advance_token();

                    const inner_expr = self.parse_expr();

                    this_expr = EXPRESSIONS {
                        .operator_expr = .{
                            .inner_operator = inner_operator,
                            .inner_expr = inner_expr,
                        }
                    };
                },

                .base_left_shift => {
                    const inner_operator = OPERATORS.LEFT_SHIFT;
                    self.advance_token();

                    const inner_expr = self.parse_expr();

                    this_expr = EXPRESSIONS {
                        .operator_expr = .{
                            .inner_operator = inner_operator,
                            .inner_expr = inner_expr,
                        }
                    };
                },

                .base_right_shift => {
                    const inner_operator = OPERATORS.RIGHT_SHIFT;
                    self.advance_token();

                    const inner_expr = self.parse_expr();

                    this_expr = EXPRESSIONS {
                        .operator_expr = .{
                            .inner_operator = inner_operator,
                            .inner_expr = inner_expr,
                        }
                    };
                },

                .base_bitwise_and => {
                    const inner_operator = OPERATORS.BITWISE_AND;
                    self.advance_token();

                    const inner_expr = self.parse_expr();

                    this_expr = EXPRESSIONS {
                        .operator_expr = .{
                            .inner_operator = inner_operator,
                            .inner_expr = inner_expr,
                        }
                    };
                },

                .base_bitwise_or => {
                    const inner_operator = OPERATORS.BITWISE_OR;
                    self.advance_token();

                    const inner_expr = self.parse_expr();

                    this_expr = EXPRESSIONS {
                        .operator_expr = .{
                            .inner_operator = inner_operator,
                            .inner_expr = inner_expr,
                        }
                    };
                },

                .keyword_and => {
                    const inner_operator = OPERATORS.AND;
                    self.advance_token();

                    const inner_expr = self.parse_expr();

                    this_expr = EXPRESSIONS {
                        .operator_expr = .{
                            .inner_operator = inner_operator,
                            .inner_expr = inner_expr,
                        }
                    };
                },

                .keyword_or => {
                    const inner_operator = OPERATORS.OR;
                    self.advance_token();

                    const inner_expr = self.parse_expr();

                    this_expr = EXPRESSIONS {
                        .operator_expr = .{
                            .inner_operator = inner_operator,
                            .inner_expr = inner_expr,
                        }
                    };
                },

                /////////////////////// OPERATOR-EXPR /////////////////// end ////






                .base_semicolon, .base_comma, .base_right_paren => { // null production
                    return_expr_ptr.* = this_expr;
                    break;
                },

                else => {
                    print("got :: {any}\n", .{tok});
                    @panic("in parse_expr, panic, unexpected expr");
                },


            }

        }

        return return_expr_ptr;

    }

    pub fn parse_block_expr(self: *Self) EXPRESSIONS {

        self.expect_advance_token(.base_left_braces);
        var block_elem = std.ArrayList(BLOCK_ELEMENTS).init(Self.default_allocator);

        while(true) {

            const tok = self.peek_token();
            switch(tok.kind) {

                // ASSIGNMENTS and UPDATES
                .base_identifier => {
                    
                    const var_name = tok.lexeme.?;
                    self.expect_advance_token(.base_identifier);

                    const tok2 = self.peek_token();
                    if(tok2.kind == .base_type_colon) { //  ASSIGNMENT
                        self.expect_advance_token(.base_type_colon);
                        const var_type = self.parse_type();

                        if(self.expect_token(.base_assign)) { // ASSIGN WITH VALUE ~ a :: i32 = 1024;
                            self.expect_advance_token(.base_assign);
                            const value = self.parse_literals();

                            self.expect_advance_token(.base_semicolon);

                            const assignment = BLOCK_ELEMENTS {
                                .ASSIGNMENT = .{
                                    .variable_name = var_name,
                                    .variable_type = var_type.*,
                                    .variable_value = value,
                                }
                            };

                            block_elem.append(assignment) catch @panic("could not add to block_elem in parse_block_expr\n");

                        } else { // ASSIGN WITHOUT VALUE ~ a :: mut i32;

                            self.expect_advance_token(.base_semicolon);

                            const assignment = BLOCK_ELEMENTS {
                                .ASSIGNMENT = .{
                                    .variable_name = var_name,
                                    .variable_type = var_type.*,
                                    .variable_value = null,
                                }
                            };

                            block_elem.append(assignment) catch @panic("could not add to block_elem in parse_block_expr\n");

                        }


                    } else if(self.is_update_operator()) { // UPDATE

                        const update_op = self.which_update_operator();
                        const update_with = self.parse_literals();
                        
                        const update = BLOCK_ELEMENTS {
                            .UPDATE = .{
                                .variable_name = var_name,
                                .UPDATE_OPERATOR = update_op,
                                .update_with = update_with,
                            }
                        };

                        self.expect_advance_token(.base_semicolon);

                        block_elem.append(update) catch @panic("could not add to block_elem in parse_block_expr\n");

                    } else { // EXPRESSION
                        
                        const expr = BLOCK_ELEMENTS {
                            .EXPRESSION = self.parse_expr().*,
                        };

                        self.expect_advance_token(.base_semicolon);

                        block_elem.append(expr) catch @panic("could not add to block_elem, in parse_block_expr\n");

                    }


                },

                .base_right_braces => break,

                else => { // EXPRESSION

                        const expr = BLOCK_ELEMENTS {
                            .EXPRESSION = self.parse_expr().*,
                        };

                        self.expect_advance_token(.base_semicolon);

                        block_elem.append(expr) catch @panic("could not add to block_elem, in parse_block_expr\n");
                },


            }

        }

        return EXPRESSIONS {
            .block_expr = .{
                .block_elements = block_elem,
            }
        };

    }

    //
    // is peek_token a binary-operator
    pub fn is_operator(self: *Self) bool {
        
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

test "parser construction" {
    var parser = Parser.raw_init_with_file("./example.ox");
    defer parser.dealloc();

    parser.expect_advance_token(.directive_mod);
    print("passed..\n\n", .{});
}

test "parse number types" {
    print("--- TEST: PARSE NUMBER TYPES\n", .{});

    var parser = Parser.init_for_tests("mut f128");
    print("{any}\n", .{parser.parse_type()});

    print("passed..\n\n", .{});
}

test "parse pointer types" {
    print("--- TEST: PARSE POINTER TYPES\n", .{});

    var parser = Parser.init_for_tests("*i32");
    const parsed_ptr = parser.parse_type();
    _ = parsed_ptr;

    // print("{any}\n", .{parsed_ptr.pointer.ptr_to});

    print("passed..\n\n", .{});
}

test "parse reference types" {
    print("--- TEST: PARSE REFERENCE TYPES\n", .{});

    var parser = Parser.init_for_tests("mut@ mut u8");
    const parsed_ref = parser.parse_type();

    print("{any}\n", .{parsed_ref.reference.reference_to});

    print("passed..\n\n", .{});
}

test "parse array types" {
    print("--- TEST: PARSE ARRAY TYPES\n", .{});

    var parser = Parser.init_for_tests("mut [1024][1024] mut char");
    const parsed_array = parser.parse_type();

    print("{any}\n", .{parsed_array.array});
    print("len  -> {s}\n", .{parsed_array.array.len});
    print("type -> {any}\n", .{parsed_array.array.lonely_type});

    print("passed..\n\n", .{});
}

test "parse struct types" {
    print("--- TEST: PARSE STRUCT TYPES\n", .{});

    var parser = Parser.init_for_tests("mut SOME_STRUCT_NAMED_LOGGER");
    const parsed_struct = parser.parse_type();

    print("{any}\n", .{parsed_struct.record});
    print("struct_name -> {s}\n", .{parsed_struct.record.record_name});

    print("passed..\n\n", .{});
}

// 
// Equivalent to parsing structs
test "parse enum types" {
    print("--- TEST: PARSE STRUCT TYPES\n", .{});

    var parser = Parser.init_for_tests("SOME_ENUM_NAMED_WARNING_LEVEL");
    const parsed_enum = parser.parse_type();

    print("{any}\n", .{parsed_enum.record});
    print("enum_name -> {s}\n", .{parsed_enum.record.record_name});

    print("passed..\n\n", .{});
}

test "parse literal numbers" {
    print("--- TEST: PARSE LITERALS NUMBERS\n", .{});

    var parser = Parser.init_for_tests("32104124E-12");
    const parsed_num_literal = parser.parse_literals();

    print("{any}\n", .{parsed_num_literal});
    print("number -> {s}\n", .{parsed_num_literal.number.inner_value});

    print("passed..\n\n", .{});
}

test "parse literal string" {
    print("--- TEST: PARSE LITERALS STRING\n", .{});

    var parser = Parser.init_for_tests("\"string osis\"");
    const parsed_string = parser.parse_literals();

    print("{any}\n", .{parsed_string});
    print("string -> {s}\n", .{parsed_string.string.inner_value});

    print("passed..\n\n", .{});
}

test "parse literal variables" {
    print("--- TEST: PARSE LITERALS VARIABLES\n", .{});

    var parser = Parser.init_for_tests("COUNTER_FOR_NETWORK_TIMEOUT");
    const parsed_var = parser.parse_literals();

    print("{any}\n", .{parsed_var});
    print("var-name -> {s}\n", .{parsed_var.variable.inner_value});

    print("passed..\n\n", .{});
}

//
// For both Structs/Enums(RECORD types)
test "parse literal member_access" {
    print("--- TEST: PARSE LITERALS MEMBER_ACCESS\n", .{});

    var parser = Parser.init_for_tests("LOGGER.WARN_LEVEL.STRING_REPRESENTATION");
    const parsed_record = parser.parse_literals();

    print("{any}\n", .{parsed_record});
    print("record_name -> {s}\n", .{parsed_record.member_access.record_type_name});

    print("member_names -> ", .{});
    for(parsed_record.member_access.members_name_in_order.items) |member_name| {
        print(".{s}", .{member_name});
    }

    print("passed..\n\n", .{});
}

test "parse simple literal expr" {
    print("--- TEST: PARSE SIMPLE LITERAL EXPR\n", .{});

    var parser = Parser.init_for_tests("1+2;");
    const parsed = parser.parse_expr().literal_expr;

    print("{any}\n::{any}\n::{any}\n", .{parsed.inner_literal, parsed.inner_expr.operator_expr, parsed.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal});

    print("passed..\n\n", .{});
}

test "parse simple literal expr2" {
    var parser = Parser.init_for_tests("STRUCTNAME.STRUCTFIELD.STRUCTFIELD2+b - ENUMNAME.SOMEFIELD;");
    const parsed = parser.parse_expr().literal_expr;

    print("{any}\n", .{parsed.inner_literal.member_access});
    print("{any}\n", .{parsed.inner_expr.operator_expr});
    print("{any}\n", .{parsed.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal});

    print("passed..\n\n", .{});
}

test "parse simple literal expr3" {
    print("--- TEST: PARSE LITERAL EXPR\n", .{});

    var parser = Parser.init_for_tests("1 >> NUM_OF_BITS + 4 / 7;");
    const parsed = parser.parse_expr();

    print("{s}\n", .{parsed.literal_expr.inner_literal.number.inner_value});
    print("{any}\n", .{parsed.literal_expr.inner_expr.operator_expr.inner_operator});
    print("{s}\n", .{parsed.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal.variable.inner_value});
    print("{any}\n", .{parsed.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_operator});
    print("{s}\n", .{parsed.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal.number.inner_value});
    print("{any}\n", .{parsed.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_operator});
    print("{s}\n", .{parsed.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal.number.inner_value});

    print("passed..\n\n", .{});
}


test "parse simple function expr3" {
    print("--- TEST: PARSE FUNCTION EXPR\n", .{});

    var parser = Parser.init_for_tests("print(COUNTER + 1, WARN_LVL_ENUM.MAX)");
    const parsed = parser.parse_expr().fn_call_expr;

    print("fn_name :: {s}\n", .{parsed.fn_name});
    print("ARG1 EXPRESSION :: \n", .{});

    print("{s} ", .{parsed.inner_expr_list.items[0].literal_expr.inner_literal.variable.inner_value});
    print("{any} ", .{parsed.inner_expr_list.items[0].literal_expr.inner_expr.operator_expr.inner_operator});
    print("{s}\n", .{parsed.inner_expr_list.items[0].literal_expr.inner_expr.operator_expr.inner_expr.literal_expr.inner_literal.number.inner_value});

    print("ARG2 EXPRESSION :: \n", .{});

    const parsed_record = parsed.inner_expr_list.items[1].literal_expr.inner_literal;

    print("{s}.", .{parsed_record.member_access.record_type_name});

    for(parsed_record.member_access.members_name_in_order.items) |member_name| {
        print("{s}", .{member_name});
    }


    print("passed..\n\n", .{});
}


test "parse simple function expr4" {
    var parser = Parser.init_for_tests("print(100 + 200 + 300, a.b.c << c.b.a and a + \"another string\", get_y() + 200);");
    const parsed = parser.parse_expr().fn_call_expr;
    _ = parsed;

    print("passed..\n\n", .{});
}

test "parse block expr" {
    print("--- TEST: PARSE BLOCK EXPR\n", .{});
    var parser = Parser.init_for_tests("{ x :: i32; }");
    const blk_elems = parser.parse_block_expr().block_expr.block_elements.items;
    
    for(blk_elems) |item| {
        print("{any}\n", .{item});
    }

    print("passed..\n\n", .{});
}

test "check-operator" {
    print("--- TEST: CHECK OPERATOR\n", .{});
    var parser = Parser.init_for_tests("<<=");
    print("{any}\n", .{parser.is_operator()});
    print("{any}\n", .{parser.is_update_operator()});

    print("passed..\n\n", .{});
}

test "check assign-expr" {
    print("--- TEST: CHECK ASSIGN_EXPRESSION\n", .{});
    var parser = Parser.init_for_tests("{ x :: i32 =1; y :: mut u8; }");
    const parsed = parser.parse_block_expr();
    _ = parsed;

    print("passed..\n\n", .{});
}


test "check update-expr" {
    print("--- TEST: CHECK UPDATE_EXPRESSION\n", .{});
    var parser = Parser.init_for_tests("{ x >>= 32; y /= \"some string\"; z :: mut f64; }");
    const parsed = parser.parse_block_expr();
    _ = parsed;

    print("passed..\n\n", .{});
}

test "check block-expr" {
    print("--- TEST: CHECK BLOCK_EXPRESSION\n", .{});
    var parser = Parser.init_for_tests("{ x >>= 32; y /= \"some string\"; z :: mut f64; a + b; 100 + 200;}");
    const parsed = parser.parse_block_expr();
    _ = parsed;

    print("passed..\n\n", .{});
}
