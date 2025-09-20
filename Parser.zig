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
                @panic("panic in parse_types\n");
            },
        }

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

        return return_literal;
    }
    

    //
    // look at next token without consuming it
    pub fn peek_token(self: *Self) Token {
        if(self.current_token_idx) |idx| {
            if(idx + 1 > Self.LEN_STREAM_TOKENS) @panic("out-of-index access in peek_token\n");
            return self.stream_tokens.items[idx + 1];
        } else return self.stream_tokens.items[0];
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
            if(idx > 0) self.current_token_idx.? -= 1;
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
}

test "parse number types" {
    print("--- TEST: PARSE NUMBER TYPES\n", .{});

    var parser = Parser.init_for_tests("mut f128");
    print("{any}\n", .{parser.parse_type()});

    print("\n\n", .{});
}

test "parse pointer types" {
    print("--- TEST: PARSE POINTER TYPES\n", .{});

    var parser = Parser.init_for_tests("mut* mut f128");
    const parsed_ptr = parser.parse_type();

    print("{any}\n", .{parsed_ptr.pointer.ptr_to});

    print("\n\n", .{});
}

test "parse reference types" {
    print("--- TEST: PARSE REFERENCE TYPES\n", .{});

    var parser = Parser.init_for_tests("mut@ mut u8");
    const parsed_ref = parser.parse_type();

    print("{any}\n", .{parsed_ref.reference.reference_to});

    print("\n\n", .{});
}

test "parse array types" {
    print("--- TEST: PARSE ARRAY TYPES\n", .{});

    var parser = Parser.init_for_tests("mut [1024][1024] mut char");
    const parsed_array = parser.parse_type();

    print("{any}\n", .{parsed_array.array});
    print("len  -> {s}\n", .{parsed_array.array.len});
    print("type -> {any}\n", .{parsed_array.array.lonely_type});

    print("\n\n", .{});
}

test "parse struct types" {
    print("--- TEST: PARSE STRUCT TYPES\n", .{});

    var parser = Parser.init_for_tests("mut SOME_STRUCT_NAMED_LOGGER");
    const parsed_struct = parser.parse_type();

    print("{any}\n", .{parsed_struct.record});
    print("struct_name -> {s}\n", .{parsed_struct.record.record_name});

    print("\n\n", .{});
}

// 
// Equivalent to parsing structs
test "parse enum types" {
    print("--- TEST: PARSE STRUCT TYPES\n", .{});

    var parser = Parser.init_for_tests("SOME_ENUM_NAMED_WARNING_LEVEL");
    const parsed_enum = parser.parse_type();

    print("{any}\n", .{parsed_enum.record});
    print("enum_name -> {s}\n", .{parsed_enum.record.record_name});

    print("\n\n", .{});
}

test "parse literal numbers" {
    print("--- TEST: PARSE LITERALS NUMBERS\n", .{});

    var parser = Parser.init_for_tests("32104124E-12");
    const parsed_num_literal = parser.parse_literals();

    print("{any}\n", .{parsed_num_literal});
    print("number -> {s}\n", .{parsed_num_literal.number.inner_value});

    print("\n\n", .{});
}

test "parse literal string" {
    print("--- TEST: PARSE LITERALS STRING\n", .{});

    var parser = Parser.init_for_tests("\"string osis\"");
    const parsed_string = parser.parse_literals();

    print("{any}\n", .{parsed_string});
    print("string -> {s}\n", .{parsed_string.string.inner_value});

    print("\n\n", .{});
}

test "parse literal variables" {
    print("--- TEST: PARSE LITERALS VARIABLES\n", .{});

    var parser = Parser.init_for_tests("COUNTER_FOR_NETWORK_TIMEOUT");
    const parsed_var = parser.parse_literals();

    print("{any}\n", .{parsed_var});
    print("var-name -> {s}\n", .{parsed_var.variable.inner_value});

    print("\n\n", .{});
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

    print("\n\n", .{});
}
