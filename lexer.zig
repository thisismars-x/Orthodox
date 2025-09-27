///// According to ./tokens.zig
///////////////////////////////////////////////////////////////
///////////////////////// LEXER ///////////////////////////////
///////////////////////////////////////////////////////////////

const tokens = @import("./tokens.zig");
const token_id = tokens.token_id;
const Token = tokens.Token;

pub usingnamespace token_id;
pub usingnamespace errors;

const errors = @import("./errors.zig");
const LexError = errors.LexError;
const LexErrorContext = errors.LexErrorContext;

const std = @import("std");
const print = std.debug.print;

//
// Tokenize stream of characters, one by one, instead of tokenizing
// the whole file at once
pub const StreamLexer = struct {
    source: []const u8,
    filename: ?[]const u8,

    // current span
    pos: u32,
    line: u32,

    // error context throughout this lexer, to record and write errors to console
    error_context: LexErrorContext,

    const Self = @This();
    const MaxSourceSizeLimit = 10_000 * 200; // 10_000 lines times 200 columns

    //
    // this allocator is used throughout the tokenization
    // process and cleared at end of program
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    const default_allocator = gpa.allocator();

    //
    // raw_init should never be called in production, only acceptable
    // in tests, where it is bothersome to create files and write to them
    pub fn raw_init(source: []const u8, filename: []const u8) Self {
        return Self{
            .source = source,
            .filename = filename,
            .pos = 0,
            .line = 1,
            .error_context = LexErrorContext.zero_init_err_context(),
        };
    }

    //
    // prepare to run tokenizer on a file by extracting its content
    pub fn init_with_file(filename: []const u8) Self {
        var source = std.fs.cwd().readFileAlloc(Self.default_allocator, filename, Self.MaxSourceSizeLimit) catch |err| {
            print("ERROR opening file with StreamLexer.init_with_file :: filename {s}, error {}\n", .{ filename, err });
            @panic("Could not open file, in init_with_file\n");
        };

        // do not delegate this to lex-ing process
        remove_comments(source[0..source.len]);

        return Self.raw_init(source, filename);
    }

    //////////////////// SCAN-SYMBOLS //////////////// start //

    //
    // this function delegates responsibility to functions based on current_token
    // and next_token
    pub fn next_token(self: *Self) Token {
        self.skip_whitespace();

        const c = self.peek() orelse
            return Token{
                .kind = .base_EOF,
                .lexeme = null,
                .span = .{ self.pos, self.line },
            };

        if (c == '@' or c == '#' or c == '?' or is_alpha(c)) {
            return self.scan_symbol();
        } else if (c == '"') {
            return self.scan_string();
        } else if (c == '\'') {
            return self.scan_char();
        } else if (is_digit(c)) {
            return self.scan_number();
        } else {
            return self.scan_base();
        }
    }

    //
    // scan keywrods, type, and directive definitions
    // common and base definitions are in scan_base
    pub fn scan_symbol(self: *Self) Token {
        const start = self.pos;

        var is_identifier = false;
        var is_directive = false;

        // ?i32 is maybe i32
        // !i32 is result i32
        // *iovec is pointer iovec
        // @iovec is refernce iovec
        switch (self.source[start]) {
            '?' => {
                _ = self.advance();
                return Token{
                    .kind = .type_maybe,
                    .lexeme = null,
                    .span = .{ self.pos, self.line },
                };
            },

            '@' => {
                _ = self.advance();
                return Token{
                    .kind = .type_reference,
                    .lexeme = null,
                    .span = .{ self.pos, self.line },
                };
            },

            '#' => is_directive = true,

            'a'...'z', 'A'...'Z', '_' => is_identifier = true,

            else => self.error_dump(LexError.InvalidToken),
        }

        while (self.peek()) |c| {
            if (is_directive) {
                if (is_alpha(c) or c == '#') {
                    _ = self.advance();
                } else break;
            } else {
                if (is_alpha_numeric(c)) {
                    _ = self.advance();
                } else break;
            }
        }

        const lexeme = self.source[start..self.pos];
        var token: Token = undefined;

        if (std.mem.eql(u8, lexeme, "break")) {
            token.kind = .keyword_break;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "case")) {
            token.kind = .keyword_case;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "mut")) {
            token.kind = .keyword_mut;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "else")) {
            token.kind = .keyword_else;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "elif")) {
            token.kind = .keyword_elif;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "loop")) {
            token.kind = .keyword_loop;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "enum")) {
            token.kind = .keyword_enum;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "for")) {
            token.kind = .keyword_for;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "in")) {
            token.kind = .keyword_in;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "if")) {
            token.kind = .keyword_if;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "return")) {
            token.kind = .keyword_return;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "struct")) {
            token.kind = .keyword_struct;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "switch")) {
            token.kind = .keyword_switch;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "while")) {
            token.kind = .keyword_while;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "fn")) {
            token.kind = .keyword_function;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "and")) {
            token.kind = .keyword_and;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "or")) {
            token.kind = .keyword_or;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "i8")) {
            token.kind = .type_i8;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "i16")) {
            token.kind = .type_i16;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "i32")) {
            token.kind = .type_i32;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "i64")) {
            token.kind = .type_i64;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "u8")) {
            token.kind = .type_u8;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "u16")) {
            token.kind = .type_u16;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "u32")) {
            token.kind = .type_u32;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "f32")) {
            token.kind = .type_f32;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "f64")) {
            token.kind = .type_f64;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "f128")) {
            token.kind = .type_f128;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "char")) {
            token.kind = .type_char;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "String")) {
            token.kind = .type_string;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "none")) {
            token.kind = .type_none;
            token.lexeme = null;
        } else if (std.mem.eql(u8, lexeme, "namespace")) {
            token.kind = .type_namespace;
            token.lexeme = null;
        } else if (is_identifier) {
            token.kind = .base_identifier;
            token.lexeme = lexeme;
        } else if (is_directive) {
            if (std.mem.eql(u8, lexeme, "#include")) {
                token.kind = .directive_include;
                token.lexeme = null;
            } else if (std.mem.eql(u8, lexeme, "#import")) {
                token.kind = .directive_import;
                token.lexeme = null;
            } else if (std.mem.eql(u8, lexeme, "#alias")) {
                token.kind = .directive_alias;
                token.lexeme = null;
            } else if (std.mem.eql(u8, lexeme, "#mod")) {
                token.kind = .directive_mod;
                token.lexeme = null;
            } else if (std.mem.eql(u8, lexeme, "#inline")) {
                token.kind = .directive_inline;
                token.lexeme = null;
            } else if (std.mem.eql(u8, lexeme, "#static")) {
                token.kind = .directive_static;
                token.lexeme = null;
            } else if (lexeme.len > 1) { // '#' is invalid
                token.kind = .directive_aliased_word;
                token.lexeme = lexeme;
            } else self.error_dump(LexError.InvalidDirective);
        }

        token.span = .{ self.pos, self.line };
        return token;
    }

    //
    // scan base_* tokens, which are basic 1-character tokens mostly
    pub fn scan_base(self: *Self) Token {
        var id: token_id = undefined;

        // no backtracking, if already called 'advance' do not call it again
        var already_skipped = false;

        switch (self.peek().?) {
            '(' => id = .base_left_paren,
            ')' => id = .base_right_paren,
            '{' => id = .base_left_braces,
            '}' => id = .base_right_braces,
            '[' => id = .base_left_bracket,
            ']' => id = .base_right_bracket,
            '&' => id = .base_bitwise_and,
            '|' => id = .base_bitwise_or,
            ',' => id = .base_comma,
            ':' => {
                _ = self.advance();

                if (self.peek()) |c| {
                    if (c == ':') {
                        id = .base_type_colon;
                    } else id = .base_colon;
                } else id = .base_colon;
            },

            ';' => id = .base_semicolon,
            '+' => id = .base_add,
            '-' => id = .base_sub,
            '/' => id = .base_div,

            '*' => {
                _ = self.advance();

                if (self.peek()) |c| {
                    if (c == '*') {
                        id = .base_exp;
                    } else {
                        id = .common_mul;
                        already_skipped = true;
                    }
                } else {
                    id = .common_mul;
                    already_skipped = true;
                }
            },

            '%' => id = .base_mod,

            '!' => {
                _ = self.advance();

                if (self.peek()) |c| {
                    if (c == '=') {
                        id = .base_not_equal;
                    } else {
                        id = .common_exclamation;
                        already_skipped = true;
                    }
                } else {
                    id = .common_exclamation;
                    already_skipped = true;
                }
            },

            '=' => {
                _ = self.advance();

                if (self.peek()) |c| {
                    if (c == '=') {
                        id = .base_equal;
                    } else {
                        id = .base_assign;
                        already_skipped = true;
                    }
                } else {
                    id = .base_assign;
                    already_skipped = true;
                }
            },

            '>' => {
                _ = self.advance();

                if (self.peek()) |c| {
                    if (c == '=') {
                        id = .base_ge;
                    } else if (c == '>') {
                        id = .base_left_shift;
                    } else {
                        id = .base_gt;
                        already_skipped = true;
                    }
                } else {
                    id = .base_gt;
                    already_skipped = true;
                }
            },

            '<' => {
                _ = self.advance();

                if (self.peek()) |c| {
                    if (c == '=') {
                        id = .base_le;
                    } else if (c == '<') {
                        id = .base_right_shift;
                    } else {
                        id = .base_lt;
                        already_skipped = true;
                    }
                } else {
                    id = .base_lt;
                    already_skipped = true;
                }
            },

            '.' => id = .base_dot,

            else => self.error_dump(LexError.InvalidToken),
        }

        if (!already_skipped) _ = self.advance();

        const tok = Token{
            .kind = id,
            .lexeme = null,
            .span = .{ self.pos, self.line },
        };

        return tok;
    }

    //
    // scans for integer numbers and float numbers
    // does not identify preceding +/- signs, as they are considered
    // as part of expressions, opposed to literal-numbers
    pub fn scan_number(self: *Self) Token {
        const start = self.pos;
        var is_float = false;

        // hex and binary numbers may not be float
        var is_bin = false;
        var is_hex = false;

        // check binary/hex prefix, sanitize string later
        if(self.peek()) |x| {
            if(x == '0') {
                _ = self.advance();

                if(self.peek()) |y| {
                    _ = self.advance(); 
                        if(self.peek()) |z| {
                            if(is_digit(z) or (z >= 'a' and z <= 'z') or (z >= 'A' and z <= 'Z')) { // 0_* may be followed by number, or hex
                                if(y == 'x' or y == 'X') { is_hex = true; }
                                else if(y == 'b' or y == 'B') { is_bin = true; }
                                else @panic("incomplete bin/hex number prefix\n");
                            }
                        }
                    
                }
            }
        }

        while (self.peek()) |c| {
            if(is_bin) {
                if(c == '0' or c == '1') { _ = self.advance(); }
                else break;

            } else if(is_hex) {
                if(is_digit(c) or (c >= 'a' and c <= 'h') or (c >= 'A' and c <= 'H')) { _ = self.advance(); }
                else break;

            } else {
                if (is_digit(c)) { _ = self.advance(); }
                else break;
            }
        }

        if (self.peek()) |c| {
            if (c == '.') {
                is_float = true;
            }
        }

        if((is_float) and (is_hex or is_bin)) @panic("no floating point allowed with bin/hex prefix\n");

        if (is_float) {
            _ = self.advance();

            if (self.peek()) |first| {
                if (!is_digit(first)) self.error_dump(LexError.MalformedNumber);
            }

            while (self.peek()) |c| {
                if (is_digit(c)) {
                    _ = self.advance();
                } else {
                    break;
                }
            }
        }

        // check for exponent part
        if (self.peek()) |is_exp| {
            if (is_exp == 'e' or is_exp == 'E') {
                is_float = true;
                _ = self.advance();

                // optional sign
                if (self.peek()) |sign| {
                    if (sign == '+' or sign == '-') _ = self.advance();
                }

                while (self.peek()) |mantissa| {
                    if (is_digit(mantissa)) {
                        _ = self.advance();
                    } else break;
                }
            }
        }

        const lexeme = self.source[start..self.pos];

        if (is_float) return Token{
            .kind = .literal_float,
            .lexeme = lexeme,
            .span = .{ self.pos, self.line },
        };

        return Token{
            .kind = .literal_number,
            .lexeme = lexeme,
            .span = .{ self.pos, self.line },
        };
    }

    //
    // scan single line string
    // multiple line strings are written like so:
    //
    // example_string :: String = "this is a big"
    //                            "multiline string"
    pub fn scan_string(self: *Self) Token {
        const start = self.pos;

        _ = self.advance();

        var string_ended = false;

        while (true) {
            const c = self.peek() orelse break;
            if (c == '"') {
                _ = self.advance();
                string_ended = true;
                break;
            }

            // escape sequences
            if (c == '\\') {
                _ = self.advance();
                if (self.peek() != null) {
                    _ = self.advance();
                } else break;
            } else {
                _ = self.advance();
            }
        }

        if (!string_ended) self.error_dump(LexError.MalformedString);

        return Token{
            .kind = .literal_string,
            .lexeme = self.source[start..self.pos],
            .span = .{ self.pos, self.line },
        };
    }

    //
    // single character within ''
    pub fn scan_char(self: *Self) Token {
        const start = self.pos;

        _ = self.advance();

        _ = self.peek().?;
        _ = self.advance();

        const c1 = self.peek().?;
        if (c1 != '\'') self.error_dump(LexError.MalformedChar);
        _ = self.advance();

        return Token{
            .kind = .literal_char,
            .lexeme = self.source[start..self.pos],
            .span = .{ self.pos, self.line },
        };
    }

    /////////////////////// SCAN-SYMBOLS //////////////// end //




    //////////////// ERROR-DUMPING /////////////////// start //////

    pub fn fmt_display_err_context(self: *Self) void {
        if (self.error_context.err) |err| {
            print("\x1b[32mError :: \x1b[31m{}\x1b[0m\n", .{err});

            if (self.error_context.dump_err) |err_msg| {
                if (self.error_context.panic) {
                    @panic(err_msg);
                } else {
                    print("{s}\n", .{err_msg});
                    errors.exit();
                }
            }
        }
    }

    pub fn write_err_context_dump_err(self: *Self) void {
        var temp_ctx_buffer: [4096]u8 = undefined;
        self.error_context.dump_err = std.fmt.bufPrint(
            &temp_ctx_buffer,
            "{s}:{d} :: {s}",
            .{ self.filename orelse "", self.line, self.get_nth_line(self.line) },
        ) catch @panic("Could not write to err_context buffer\n");
    }

    pub fn error_dump(self: *Self, err: LexError) void {
        self.error_context.err = err;
        self.write_err_context_dump_err();
        self.fmt_display_err_context();
    }

    ////////////////// ERROR-DUMPING //////////////////// end //////



    /////////////// ACCESSORY_FUNCTIONS /////////////// start /////

    pub fn is_alpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c == '_');
    }

    pub fn is_digit(c: u8) bool {
        return (c >= '0' and c <= '9');
    }

    pub fn is_alpha_numeric(c: u8) bool {
        return (is_alpha(c) or is_digit(c));
    }

    pub fn get_nth_line(self: *Self, n: usize) []const u8 {
        var start_pos: usize = 0;
        var end_pos: usize = 0;

        var total_lines: usize = 0;
        while (start_pos < self.source.len) : (start_pos += 1) {
            if (self.source[start_pos] == '\n') {
                total_lines += 1;
                if (total_lines == n - 1) break;
            }
        }

        total_lines = 0;
        while (end_pos < self.source.len) : (end_pos += 1) {
            if (self.source[end_pos] == '\n') {
                total_lines += 1;
                if (total_lines == n) break;
            }
        }

        return self.source[start_pos + 1 .. end_pos];
    }

    //
    // '//' type comments
    pub fn remove_comments(source: []u8) void {
        var i: usize = 0;
        while (i < source.len) : (i += 1) {
            if (i + 1 < source.len and source[i] == '/' and source[i + 1] == '/') {
                var j = i;
                while (j < source.len and source[j] != '\n') : (j += 1) {
                    source[j] = ' ';
                }
                i = j;
            }
        }
    }

    //
    // look at next token without consuming
    pub fn peek(self: *Self) ?u8 {
        if (self.pos >= self.source.len) return null;
        return self.source[self.pos];
    }

    //
    // consume current token
    pub fn advance(self: *Self) ?u8 {
        const c = peek(self) orelse return null;
        self.pos += 1;
        return c;
    }

    //
    // ignore whitespace, identation has no special meaning
    pub fn skip_whitespace(self: *Self) void {
        while (self.peek()) |c| {
            switch (c) {
                ' ', '\t' => _ = self.advance(),

                '\n' => {
                    _ = self.advance();
                    self.line += 1;
                },

                else => break,
            }
        }
    }

    ////////////////// ACCESSORY_FUNCTIONS /////////////// end /////

};


//////////////////////////////////////////////////////////////////
//// LEXER TESTS ///////// LEXER TESTS ///////// LEXER TESTS /////
//////////////////////////////////////////////////////////////////

// test "next token" {
//     var lexer = StreamLexer.init_with_file("./example.ox");
//
//     while (true) {
//         const token = lexer.next_token();
//         if (token.kind == .base_EOF) return;
//         print("Token-id: {}, Token-lexeme {any}, span<line_number {d}, pos {d}>\n", .{ token.kind, token.lexeme, token.span[1], token.span[0] });
//     }
// }
//
// test "scan symbol" {
//     var lexer = StreamLexer.raw_init("#bool", "file");
//     const token = lexer.scan_symbol();
//
//     print("Token-id: {}, Token-lexeme {s}\n", .{ token.kind, token.lexeme.? });
// }
//
// test "scan string" {
//     var lexer = StreamLexer.raw_init("\"this is a string that will stretch \n multiple lines so what\"", "opt-file");
//     const token = lexer.scan_string();
//
//     print("Token-id: {}, Token-lexeme {s}\n", .{ token.kind, token.lexeme.? });
// }
//
// test "scan number" {
//     var lexer = StreamLexer.raw_init("0b00001000", "some-file");
//     const token = lexer.scan_number();
//
//     print("Token-id: {}, Token-lexeme {s}\n", .{ token.kind, token.lexeme.? });
// }
