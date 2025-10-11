/////////////////////////////////////////////////////////
//////// LEX-ERROR ////////////////////////// START /////
/////////////////////////////////////////////////////////

const std = @import("std");
const proc = std.process;

//
// C style exit without unwinding the stack like @panic
// non-zero error code displays unnecessary traces
pub fn exit() void {
    proc.exit(0);
}

pub const LexError = error {
    MalformedNumber,
    MalformedString,
    MalformedChar,
    EmptyChar,
    InvalidToken,
    InvalidDirective,
};

pub const LexErrorContext = struct {
    err: ?LexError,
    dump_err: ?[]const u8,

    const Self = @This();

    pub fn zero_init_err_context() Self {
        return Self{
            .err = null,
            .dump_err = null,
        };
    }
};

// simpleton error, throughout parser ----- end
pub fn exit_with_msg(msg: []const u8) void {
    std.debug.print("{s}\n", .{msg});
    proc.exit(1);
}

/////////////////////////////////////////////////////////
//////// LEX-ERROR ////////////////////////// END ///////
/////////////////////////////////////////////////////////


