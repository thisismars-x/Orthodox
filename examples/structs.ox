
//
// which ISP do you use, and does it work
wifi :: struct {
    ISP         :: String,
    status      :: #bool,

    // throughput consumption through the day(>12am)
    // to night(>12pm)
    consumption :: [2]f32,
};

#alias u8 bool

main :: proc() int {

    some :: mut wifi; 
    some.status = 0;
    some.ISP = "vianet";

    // %s expects a const char^ not a string
    "the user uses %s with status %d\n", cStr(some.ISP), some.status;

    some.ISP = "another wifi";
    "the user uses %s with status %d\n", cStr(some.ISP), some.status;
    
    some.consumption[0] = 80;
    some.consumption[1] = 100 - some.consumption[0];

    "the throughput consumed at day :: %.4f\n", some.consumption[0];
    "the throughput consumed at day :: %.4f\n", some.consumption[1];

    other :: mut wifi = wifi {
        .ISP = "vianet",
        .status = 0,
    };

    other.consumption[0] = some.consumption[1];
    other.consumption[1] = some.consumption[0];
};
