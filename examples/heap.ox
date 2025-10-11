
main :: proc() int {
  #static number :: i32 = 0;

  list_of_numbers :: ^mut i32 = #cast (^mut i32)mAlloc(sizeof(number) * 100);
  
  for i in 0 : 100 : {
    list_of_numbers[i] = i + 1;
  }

  for i in 0 : 100 : {
    "list_of_numbers[%d] = %d\n", i, list_of_numbers[i]; 
  }
};
