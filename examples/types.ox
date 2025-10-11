
//
// Everything is strictly typed in Orthodox, no 'subtle types'
// Everything is concrete
//
// main is a variable bound to type () -> int, assigned to a block
// main should always be () -> int
main :: proc() int {

  // types are const. by default
  // there are no weeks with more or less than 7 days
  NO_OF_DAYS_IN_A_WEEK :: u8 = 7;

  // integers are also size-constrained,
  // i8, i16, i32, i64
  counter :: mut i32 = 0;

  for i in 0 : 100 : {
    if is_even(i) : {
      counter += 1;
    }
  }

  // pointers use ^ syntax
  counter_num :: ^mut i32 = @counter;

  "the number of even numbers in range 0 : 100 are %d\n", ^counter_num;

};

//
// reference types look like so,
// @i32 -> const i32&, to the familiar C-novice
#inline is_even :: proc(number :: @i32) #bool {
  
  if number % 2 == 0 : {
    return #true; 
  } else : {
    return #false;
  }

};

// 
// aliases are simple and evaluated pre-compilation
#alias u8   bool
#alias 0    false
#alias 1    true
