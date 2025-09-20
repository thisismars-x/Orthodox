const proc = @import("std").process;


// 
// non zero error code displays a bunch of trace which
// we do not need
const ERR_OCCURED = 0;

//
// C style exit without unwinding the stack like @panic
pub fn exit() void {
    proc.exit(ERR_OCCURED);
}

 
pub const LexError = error {
    MalformedNumber,
    MalformedString,
    MalformedChar,
    InvalidToken,
    InvalidDirective,
};

pub const LexErrorContext = struct {
    err: ?LexError,
    dump_err: ?[]const u8,
    panic: bool,

    const Self = @This();

    pub fn zero_init_err_context() Self {
        return Self{
            .err = null,
            .dump_err = null,
            .panic = false,
        };
    }
};
