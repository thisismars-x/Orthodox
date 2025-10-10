
logger :: struct {
  warn :: String,
  level :: u8,
  pipe_to_file :: FileHandle,
};

//
// file_handle to STDFILENO
FileHandle :: enum { STDIN, STDOUT, STDERR, };

main :: proc(argc :: u32, args :: [64]String) void {

  a :: mut i32 = FileHandle.STDIN;
   
  loop : {
    a += 1;

//    if a + 200 : {
//      break;
//    }
  }

  scoped_logger :: logger = logger {
    .warn = "yes",
    .level = 0,
    .pipe_to_file = FileHandle.STDERR,
  };

};

print_array_of_strings :: proc() void {

  for i in 0 : 128 : {
    x :: mut i64;
    break;
  }

  "stringosis";

  a :: mut i32 = x.y.z[200];
  a = a[300];
  a = a[400];

  return;

};

add :: proc(i :: i32, j :: i32) i32 {
  add(i, j, 'c', "de", 100.24 * 2 - 3 ** 2, 100 and 200 & 500, some.structfield[i + j]);
  return i + j + k >> 3;
};
