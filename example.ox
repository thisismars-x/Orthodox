#mod example/main
#alias bool u8

stdio :: namespace = #include<stdio.h> 

#inline list_till_hundred :: fn() void = {
  for i in 0 : 100 {
    "%d", i
  }
};

is_even :: fn(number @i32) #bool = {
  return number % 2 == 0;
};

logger :: struct = {
  level :: u8, // 0, 1, 2
  msg :: String,
  debug_with_panic :: bool,
};

default_logger :: fn() = {
  return logger {
    .level = 1,
    .msg = "$$ error occured at line 12 $$",
    .debug_with_panic = true,
  };
}

//
// Change terminal state
terminal_mutate :: fn() = {
  #static old_term_state :: TermState = get_term_state();
  // mutate
};

main :: fn(args i32, argv []string) = {
  
  i :: mut usize;
  while(i <= args) {
    // do some work
  }

  some :: ?logger = loop {
    // infinite loop
  }

  if (some-cond) {

  } elif(other-cond) {
  
  } else {}

  some :: char = 'a';
  other :: String = "this is a string" / "add another string";

};
