
level :: enum {
    LEVEL_O,
    LEVEL_1,
    LEVEL_2,
};

main :: proc() int {
  
    logger :: level = LEVEL_2;

    if logger == LEVEL_2 : {
        "logger level 2, level 2, level 2\n";
    }

};
