///////////////////////////////
//////// LEX-ERROR ////////////////////////// START /////
///////////////////////////////

const proc = @import("std").process;

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

             ///////////////////////////////////////////
//////// END //////////////////// LEX-ERROR ////////////
             //////////////////////////////////////////


