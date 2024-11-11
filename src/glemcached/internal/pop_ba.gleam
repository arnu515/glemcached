import gleam/option.{type Option, None, Some}

// TODO: make these pop_until functions generic over any string
// (help needed)
pub fn pop_until_space_on_same_line(
  ba: BitArray,
) -> Option(#(BitArray, BitArray)) {
  do_pop_until_space_on_same_line(<<>>, ba)
}

fn do_pop_until_space_on_same_line(left: BitArray, right: BitArray) {
  case right {
    <<" ", right:bits>> -> Some(#(left, right))
    <<"\r\n", _:bits>> -> None
    <<a, right:bits>> ->
      do_pop_until_space_on_same_line(<<left:bits, a>>, right)
    _ -> None
  }
}

pub fn pop_until_rn(ba: BitArray) -> Option(#(BitArray, BitArray)) {
  do_pop_until_rn(<<>>, ba)
}

fn do_pop_until_rn(left: BitArray, right: BitArray) {
  case right {
    <<"\r\n", right:bits>> -> Some(#(left, right))
    <<a, right:bits>> -> do_pop_until_rn(<<left:bits, a>>, right)
    _ -> None
  }
}
